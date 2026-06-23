-- Auto-Debug: resolve or discover a DAP launch/attach config for the current
-- buffer's filetype, then start debugging — gated so nothing the model emits
-- ever runs without an explicit, content-hashed human confirm.
--
-- AUTHORITATIVE SPEC: ~/proj/pc-tune/_reports/nvim-autodebug/SYNTHESIS.md
-- ("Folded checklist v1 — BUILD"). Architecture = state-dir cache + exec gates.
--
-- Security invariants (see SYNTHESIS §2):
--   * Discovery is read-only (`--allowedTools "Read,Glob,Grep"`, no Write/Bash).
--   * Persisted config is JSON, loaded by FIXED `vim.json.decode` — NEVER loadstring.
--   * Nothing non-builtin runs without a confirm surfacing the literal command,
--     re-confirmed whenever the resolved {program,args,cwd} hash changes.
--   * Attach configs NEVER auto-select processId — always human pick_process.
--   * build_cmd / run_cmd are DISPLAY-ONLY — never passed to vim.system/os.execute.
--
-- The pure logic (sha1, decide, validate_config, fingerprint, cache_*,
-- needs_reconfirm, exec_descriptor, dap_config) is dependency-free and is what
-- the headless tests in .fleet/notes/tests/ prove. The interactive/async path
-- (auto_debug, discover, confirm dialogs) is manual-tested.

local M = {}

-- ---------------------------------------------------------------------------
-- Manifests used to locate the project root and fingerprint it.
-- ---------------------------------------------------------------------------
M.MANIFESTS = {
  "*.sln", "*.slnx", "*.csproj", "*.fsproj", -- .NET
  "pyproject.toml", "setup.py", "requirements.txt", -- Python
  "package.json", "deno.json", -- Node/Deno
  "go.mod", "Cargo.toml", "build.gradle", "pom.xml", "CMakeLists.txt",
  ".git",
}

-- Keys that nvim-dap actually understands. dap_config() copies ONLY these, so a
-- discovered config can never smuggle an executable string (build_cmd/run_cmd)
-- into the table handed to dap.run(). Whitelist, not blacklist — deliberate.
local DAP_KEYS = {
  type = true, name = true, request = true, program = true, args = true,
  cwd = true, env = true, envFile = true, console = true, stopAtEntry = true,
  port = true, host = true, webRoot = true, sourceMapPathOverrides = true,
  justMyCode = true, stopOnEntry = true, runtimeExecutable = true,
  runtimeArgs = true, address = true, MIMode = true, miDebuggerPath = true,
  -- NOTE: processId is intentionally NOT here — attach always injects
  -- pick_process at run time; a model-supplied processId is dropped.
}

-- ---------------------------------------------------------------------------
-- sha1 — pure LuaJIT bit implementation (no built-in vim sha1; sha256 exists
-- but the spec keys the cache file + confirm hash on sha1). Known-answer
-- tested: sha1("abc") == "a9993e364706816aba3e25717850c26c9cd0d89d".
-- ---------------------------------------------------------------------------
function M.sha1(msg)
  local bit = require("bit")
  local band, bor, bxor, bnot, rol = bit.band, bit.bor, bit.bxor, bit.bnot, bit.rol
  local lshift, rshift, tobit = bit.lshift, bit.rshift, bit.tobit
  local h0, h1, h2, h3, h4 =
    0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0

  local msglen = #msg
  msg = msg .. "\128"
  while (#msg % 64) ~= 56 do
    msg = msg .. "\0"
  end
  local function put32(n)
    return string.char(
      band(rshift(n, 24), 0xff), band(rshift(n, 16), 0xff),
      band(rshift(n, 8), 0xff), band(n, 0xff)
    )
  end
  -- 64-bit bit-length; high word is 0 for any realistic path string.
  local hi = math.floor(msglen / 0x20000000) -- (msglen*8) >> 32
  local lo = tobit((msglen * 8) % 0x100000000)
  msg = msg .. put32(hi) .. put32(lo)

  for chunk = 1, #msg, 64 do
    local w = {}
    for i = 0, 15 do
      local p = chunk + i * 4
      w[i] = bor(
        lshift(msg:byte(p), 24), lshift(msg:byte(p + 1), 16),
        lshift(msg:byte(p + 2), 8), msg:byte(p + 3)
      )
    end
    for i = 16, 79 do
      w[i] = rol(bxor(w[i - 3], w[i - 8], w[i - 14], w[i - 16]), 1)
    end
    local a, b, c, d, e = h0, h1, h2, h3, h4
    for i = 0, 79 do
      local f, k
      if i < 20 then
        f = bor(band(b, c), band(bnot(b), d)); k = 0x5A827999
      elseif i < 40 then
        f = bxor(b, c, d); k = 0x6ED9EBA1
      elseif i < 60 then
        f = bor(bor(band(b, c), band(b, d)), band(c, d)); k = 0x8F1BBCDC
      else
        f = bxor(b, c, d); k = 0xCA62C1D6
      end
      local temp = tobit(rol(a, 5) + f + e + k + w[i])
      e = d; d = c; c = rol(b, 30); b = a; a = temp
    end
    h0 = tobit(h0 + a); h1 = tobit(h1 + b); h2 = tobit(h2 + c)
    h3 = tobit(h3 + d); h4 = tobit(h4 + e)
  end

  local function hx(n)
    return string.format("%08x", n % 0x100000000)
  end
  return hx(h0) .. hx(h1) .. hx(h2) .. hx(h3) .. hx(h4)
end

-- ---------------------------------------------------------------------------
-- State-dir cache  (stdpath("state")/autodebug/<sha1(root)>.json)
-- ---------------------------------------------------------------------------
function M.cache_dir()
  return vim.fs.joinpath(vim.fn.stdpath("state"), "autodebug")
end

function M.cache_path(root)
  return vim.fs.joinpath(M.cache_dir(), M.sha1(root) .. ".json")
end

-- Fingerprint = sorted list of {name,size,mtime} for the manifest files at root.
-- Drift (retarget, host moved) → fingerprint mismatch → cache miss → rediscover.
function M.fingerprint(root)
  local entries = {}
  for _, pat in ipairs(M.MANIFESTS) do
    if pat ~= ".git" then
      for _, path in ipairs(vim.fn.glob(vim.fs.joinpath(root, pat), false, true)) do
        local st = vim.uv.fs_stat(path)
        if st then
          entries[#entries + 1] = {
            name = vim.fs.basename(path),
            size = st.size,
            mtime = st.mtime and st.mtime.sec or 0,
          }
        end
      end
    end
  end
  table.sort(entries, function(a, b)
    if a.name == b.name then return a.size < b.size end
    return a.name < b.name
  end)
  return entries
end

-- Canonical, comparable string form of a fingerprint.
function M.fingerprint_string(fp)
  local parts = {}
  for _, e in ipairs(fp) do
    parts[#parts + 1] = string.format("%s:%d:%d", e.name, e.size, e.mtime)
  end
  return table.concat(parts, "|")
end

-- FIXED decoder. pcall-wrapped so a corrupt cache never aborts startup, and
-- vim.json.decode — never loadstring/dofile (the whole point of the state-dir
-- architecture: persisted config is data, never code).
function M.cache_read(root)
  local path = M.cache_path(root)
  local fd = io.open(path, "r")
  if not fd then return nil end
  local raw = fd:read("*a")
  fd:close()
  if not raw or raw == "" then return nil end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" then return nil end
  return decoded
end

function M.cache_write(root, entry)
  vim.fn.mkdir(M.cache_dir(), "p")
  local path = M.cache_path(root)
  local fd = io.open(path, "w")
  if not fd then return false end
  fd:write(vim.json.encode(entry))
  fd:close()
  return true
end

-- ---------------------------------------------------------------------------
-- Exec descriptor + confirm hash  (what the run-gate surfaces and pins)
-- ---------------------------------------------------------------------------
-- The literal command a launch config WILL run. build_cmd/run_cmd are NOT read
-- here — they are display-only suggestions, never part of what executes.
function M.exec_descriptor(cfg)
  return {
    program = cfg.program or "",
    args = cfg.args or {},
    cwd = cfg.cwd or "",
  }
end

function M.confirm_hash(cfg)
  local d = M.exec_descriptor(cfg)
  local args = type(d.args) == "table" and table.concat(d.args, "\31") or tostring(d.args)
  return M.sha1(table.concat({ cfg.type or "", cfg.request or "", d.program, args, d.cwd }, "\30"))
end

-- Re-confirm whenever the resolved exec hash differs from the stored one (or
-- there is none). NOT one-time — defeats the persistence-bypass (CON A4/A7).
function M.needs_reconfirm(entry, cfg)
  if type(entry) ~= "table" or not entry.confirmed_hash then return true end
  return entry.confirmed_hash ~= M.confirm_hash(cfg)
end

-- ---------------------------------------------------------------------------
-- Config validation — shape + `type` must be a known adapter (Q4).
-- `known` is an explicit set so this stays pure/testable; the live caller
-- passes M.known_types().
-- ---------------------------------------------------------------------------
function M.validate_config(cfg, known)
  if type(cfg) ~= "table" then return false, "config is not a table" end
  if type(cfg.type) ~= "string" or cfg.type == "" then return false, "missing type" end
  if type(cfg.request) ~= "string" then return false, "missing request" end
  if cfg.request ~= "launch" and cfg.request ~= "attach" then
    return false, "request must be launch|attach"
  end
  if known and not known[cfg.type] then
    return false, "unknown adapter type: " .. cfg.type
  end
  if cfg.request == "launch" and (type(cfg.program) ~= "string" or cfg.program == "") then
    return false, "launch config needs a program"
  end
  return true
end

-- Live known-adapter set: configured dap adapters + a static allowlist of
-- well-known types the schema may emit. Membership is the gate, availability
-- (binary installed) is checked separately by the run-time adapter guard.
function M.known_types()
  local known = {
    coreclr = true, netcoredbg = true, ["pwa-node"] = true,
    ["pwa-chrome"] = true, python = true, debugpy = true,
    cppdbg = true, lldb = true, codelldb = true, go = true, delve = true,
  }
  local ok, dap = pcall(require, "dap")
  if ok then
    for name in pairs(dap.adapters or {}) do
      known[name] = true
    end
  end
  return known
end

-- ---------------------------------------------------------------------------
-- dap_config — the table actually handed to dap.run(). Copies ONLY DAP_KEYS,
-- so build_cmd/run_cmd/notes can never reach the debugger. For attach, drops
-- any model-supplied processId; the caller injects pick_process.
-- ---------------------------------------------------------------------------
function M.dap_config(cfg)
  local out = {}
  for k, v in pairs(cfg) do
    if DAP_KEYS[k] then out[k] = v end
  end
  out.name = out.name or "Auto-Debug"
  return out
end

-- ---------------------------------------------------------------------------
-- Resolver — precedence builtin > vscode > cache > none (returns tagged source)
-- ---------------------------------------------------------------------------
-- Pure decision given gathered sources; trivially testable.
function M.decide(sources)
  if sources.builtin then return { source = "builtin" } end
  if sources.vscode then return { source = "vscode", config = sources.vscode } end
  if sources.cache then return { source = "cache", config = sources.cache } end
  return { source = "none" }
end

-- Read .vscode/launch.json read-only via dap.ext.vscode (free type→adapter map).
local function vscode_config(ft, root)
  local launch = vim.fs.joinpath(root, ".vscode", "launch.json")
  if vim.fn.filereadable(launch) == 0 then return nil end
  local ok, vscode = pcall(require, "dap.ext.vscode")
  if not ok then return nil end
  pcall(vscode.load_launchjs, launch)
  local dap = require("dap")
  local list = dap.configurations[ft]
  if list and list[1] then return list[1] end
  return nil
end

function M.resolve(ft, root)
  local sources = {}

  local ok, dap = pcall(require, "dap")
  if ok and dap.configurations[ft] and next(dap.configurations[ft]) ~= nil then
    sources.builtin = true
  end

  if not sources.builtin then
    sources.vscode = vscode_config(ft, root)
  end

  if not sources.builtin and not sources.vscode then
    local entry = M.cache_read(root)
    if entry and entry.config then
      local current = M.fingerprint_string(M.fingerprint(root))
      if entry.fingerprint == current then
        sources.cache = entry -- carries config + confirmed_hash
      end
    end
  end

  return M.decide(sources)
end

-- ---------------------------------------------------------------------------
-- Discovery — headless `claude-profile -p` via async vim.system, read-only.
-- Returns the validated config table (from .structured_output) via cb, or
-- cb(nil, err). NO --permission-mode plan; --json-schema is an INLINE string.
-- ---------------------------------------------------------------------------
function M.schema_json()
  return vim.json.encode({
    type = "object",
    properties = {
      type = { type = "string", description = "dap adapter type, e.g. coreclr, python, pwa-node" },
      request = { type = "string", enum = { "launch", "attach" } },
      name = { type = "string" },
      program = { type = "string", description = "absolute path to the built artifact / entry to launch" },
      args = { type = "array", items = { type = "string" } },
      cwd = { type = "string" },
      env = { type = "object" },
      stopAtEntry = { type = "boolean" },
      build_cmd = { type = "string", description = "DISPLAY ONLY shell command to build; never executed automatically" },
      run_cmd = { type = "string", description = "DISPLAY ONLY shell command to run; never executed automatically" },
      notes = { type = "string" },
    },
    required = { "type", "request" },
  })
end

local function installed_adapters_blurb()
  local lines = { "Installed/known DAP adapters in this nvim:" }
  local ok, dap = pcall(require, "dap")
  if ok then
    local names = vim.tbl_keys(dap.adapters or {})
    table.sort(names)
    lines[#lines + 1] = "  adapters: " .. table.concat(names, ", ")
  end
  local mok, reg = pcall(require, "mason-registry")
  if mok and reg.get_installed_package_names then
    local pkgs = reg.get_installed_package_names()
    table.sort(pkgs)
    lines[#lines + 1] = "  mason: " .. table.concat(pkgs, ", ")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Emit ONE config whose `type` is one of those adapters. Exemplar:"
  lines[#lines + 1] = [[{"type":"coreclr","request":"launch","name":"Launch","program":"/abs/path/bin/Debug/net8.0/App.dll","cwd":"/abs/path","stopAtEntry":false}]]
  lines[#lines + 1] = "build_cmd/run_cmd are shown to the human only and are NEVER executed."
  return table.concat(lines, "\n")
end

function M.discover(root, cb)
  if vim.fn.executable("claude-profile") == 0 then
    return cb(nil, "claude-profile not on PATH")
  end
  local prompt = table.concat({
    "Scan this repository (read-only) and produce a single nvim-dap debug",
    "configuration for the primary runnable target. Identify the adapter type,",
    "launch vs attach, the built artifact path to launch (program), cwd, args,",
    "and any env. If a build step is needed, put it in build_cmd (display only).",
    "Return ONLY the structured object matching the schema.",
  }, " ")

  local cmd = {
    "claude-profile", "-p", prompt,
    "--output-format", "json",
    "--json-schema", M.schema_json(), -- INLINE json string, not a path
    "--allowedTools", "Read,Glob,Grep",
    "--append-system-prompt", installed_adapters_blurb(),
  }

  vim.system(cmd, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return cb(nil, "claude-profile exited " .. tostring(res.code) .. ": " .. (res.stderr or ""))
      end
      local ok, env = pcall(vim.json.decode, res.stdout or "")
      if not ok or type(env) ~= "table" then
        return cb(nil, "could not parse claude-profile JSON envelope")
      end
      local cfg = env.structured_output
      if type(cfg) ~= "table" then
        return cb(nil, "no .structured_output in response")
      end
      cb(cfg)
    end)
  end)
end

-- ---------------------------------------------------------------------------
-- Start routing — per-ft starters, default dap.continue; cs → dotnet util.
-- ---------------------------------------------------------------------------
M.starters = {
  cs = function()
    require("util.dotnet-debug").debug_with_terminal()
  end,
}

function M.start(ft)
  local starter = M.starters[ft]
  if starter then return starter() end
  require("dap").continue()
end

-- Run a resolved (non-builtin) config: adapter-presence guard → confirm hash
-- has already been checked by the caller → dap.run with attach safety.
function M.run_resolved(cfg)
  local dap = require("dap")
  if not dap.adapters[cfg.type] and vim.fn.exepath(cfg.type) == "" then
    local pkg = ({ coreclr = "netcoredbg", netcoredbg = "netcoredbg",
      python = "debugpy", debugpy = "debugpy", ["pwa-node"] = "js-debug-adapter",
      ["pwa-chrome"] = "js-debug-adapter", codelldb = "codelldb" })[cfg.type] or cfg.type
    vim.notify(
      ("Auto-Debug: adapter '%s' not installed. Run :MasonInstall %s"):format(cfg.type, pkg),
      vim.log.levels.ERROR
    )
    return false
  end
  local run = M.dap_config(cfg)
  if run.request == "attach" then
    -- NEVER auto-select a processId — always human pick.
    run.processId = require("dap.utils").pick_process
  end
  dap.run(run)
  return true
end

-- ---------------------------------------------------------------------------
-- Confirm dialogs (interactive — manual-tested)
-- ---------------------------------------------------------------------------
local WORK_HINTS = { "/work", "/client", "/clients" }

local function looks_like_work(root)
  for _, h in ipairs(WORK_HINTS) do
    if root:find(h, 1, true) then return true end
  end
  return false
end

local function confirm_run(cfg)
  local d = M.exec_descriptor(cfg)
  local args = type(d.args) == "table" and table.concat(d.args, " ") or tostring(d.args)
  local msg = ("WILL EXECUTE:\n  %s %s\nin %s\n\nProceed?"):format(d.program, args, d.cwd)
  return vim.fn.confirm(msg, "&Yes\n&No", 2) == 1
end

local function confirm_discovery(root)
  local warn = looks_like_work(root) and "\n\n⚠ This path looks like work/client code." or ""
  local msg = ("Discover debug config with Claude?\n(~30–120s, sends repo contents to the API)%s\n\nProceed?")
    :format(warn)
  return vim.fn.confirm(msg, "&Yes\n&No", 2) == 1
end

-- ---------------------------------------------------------------------------
-- Top-level entry  (<leader>dA)
-- ---------------------------------------------------------------------------
M._in_progress = false

-- Run a non-builtin config through the full run gate: validate → confirm-hash
-- (re-confirm on change) → surface literal command → persist confirmed hash.
local function gated_run(ft, root, cfg, source, prior_entry)
  local ok, err = M.validate_config(cfg, M.known_types())
  if not ok then
    vim.notify("Auto-Debug: rejected config — " .. err, vim.log.levels.ERROR)
    return
  end
  if M.needs_reconfirm(prior_entry, cfg) then
    if not confirm_run(cfg) then
      vim.notify("Auto-Debug: cancelled.", vim.log.levels.INFO)
      return
    end
  end
  if not M.run_resolved(cfg) then return end
  -- Persist (cache source) or refresh confirmed hash for next time.
  if source ~= "vscode" then
    M.cache_write(root, {
      config = cfg,
      fingerprint = M.fingerprint_string(M.fingerprint(root)),
      confirmed_hash = M.confirm_hash(cfg),
    })
  end
end

function M.auto_debug()
  if M._in_progress then
    vim.notify("Auto-Debug already in progress…", vim.log.levels.WARN)
    return
  end
  local ft = vim.bo.filetype
  if ft == "" then
    vim.notify("Auto-Debug: no filetype on this buffer.", vim.log.levels.WARN)
    return
  end
  local root = vim.fs.root(0, M.MANIFESTS) or vim.fn.getcwd()

  local resolved = M.resolve(ft, root)

  if resolved.source == "builtin" then
    return M.start(ft) -- trusted; reproduces existing flow (cs → dotnet util)
  end

  if resolved.source == "vscode" or resolved.source == "cache" then
    local prior = resolved.source == "cache" and M.cache_read(root) or nil
    return gated_run(ft, root, resolved.config, resolved.source, prior)
  end

  -- source == "none" → discovery (opt-in egress + cost consent)
  if vim.fn.executable("claude-profile") == 0 then
    vim.notify("Auto-Debug: claude-profile not on PATH; cannot discover.", vim.log.levels.ERROR)
    return
  end
  if not confirm_discovery(root) then
    vim.notify("Auto-Debug: discovery cancelled.", vim.log.levels.INFO)
    return
  end

  M._in_progress = true
  vim.notify("Auto-Debug: discovering config with Claude (~30–120s)…", vim.log.levels.INFO)
  M.discover(root, function(cfg, err)
    M._in_progress = false
    if not cfg then
      vim.notify("Auto-Debug: discovery failed — " .. (err or "unknown"), vim.log.levels.ERROR)
      return
    end
    gated_run(ft, root, cfg, "discovered", nil)
  end)
end

return M
