-- Build + run + auto-attach workflow for .NET projects (Blazor Server, console, ASP.NET).
-- Runs the app outside nvim when a multiplexer is available (tmux window on
-- Linux, WezTerm tab on Windows), otherwise in a visible toggleterm split so
-- Console.ReadKey / ReadLine work normally. Either way `dotnet run` starts
-- without DOTNET_EnableDiagnostics; netcoredbg attaches by PID regardless.
local M = {}

local is_win = vim.fn.has("win32") == 1

local debug_terminal = nil

---Pane id of the WezTerm tab spawned by spawn_wezterm_tab, so stop_terminal can
---close it. The tab is started with -NoExit/`exec $SHELL` so build errors stay
---readable after the app exits, which means nothing reaps it on its own.
local debug_pane_id = nil

---pwsh (7+) if present, else Windows PowerShell. Only used on Windows.
local function powershell_exe()
  for _, exe in ipairs({ "pwsh", "powershell" }) do
    if vim.fn.executable(exe) == 1 then return exe end
  end
  return nil
end

local function find_csproj()
  -- 1. Walk up from current buffer's dir looking for a .csproj
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path ~= "" then
    local start = vim.fn.fnamemodify(buf_path, ":p:h")
    local found = vim.fs.find(function(name) return name:match("%.csproj$") end, {
      upward = true,
      path = start,
      type = "file",
      limit = 1,
    })
    if found and found[1] then
      return found[1], vim.fn.fnamemodify(found[1], ":h")
    end
  end

  -- 2. Fallback: glob downward from cwd. Prefer a runnable host project
  -- (Sdk="Microsoft.NET.Sdk.Web" or OutputType=Exe) over libraries/WASM clients.
  local cwd = vim.fn.getcwd()
  local files = vim.fn.glob(cwd .. "/**/*.csproj", false, true)
  if #files == 0 then return nil, nil end

  local function score(path)
    local f = io.open(path, "r")
    if not f then return 0 end
    local content = f:read("*a") or ""
    f:close()
    if content:match('Sdk%s*=%s*"Microsoft%.NET%.Sdk%.Web"') then return 3 end
    if content:match("<OutputType>%s*Exe%s*</OutputType>") then return 2 end
    if content:match('Sdk%s*=%s*"Microsoft%.NET%.Sdk%.BlazorWebAssembly"') then return 0 end
    return 1
  end

  table.sort(files, function(a, b) return score(a) > score(b) end)
  return files[1], vim.fn.fnamemodify(files[1], ":h")
end

local function project_name_of(csproj_path)
  return vim.fn.fnamemodify(csproj_path, ":t:r")
end

-- Prefer the process actually running the compiled DLL (the real app),
-- not the `dotnet run` launcher — attaching to the launcher means
-- breakpoints never resolve because user code never loads in that pid.

---Windows has no pgrep. `dotnet run` on Windows builds an apphost, so the real
---app is `<Project>.exe` while `dotnet.exe` is only the launcher (plus MSBuild
---nodes) — matching on image name is both faster and more precise than a
---command-line scan. tasklist runs in ~50ms; the PowerShell/CIM fallback is
---only needed for `dotnet <Project>.dll`, which has no apphost and can only be
---identified by its command line.
local function find_pid_win(project_name)
  local res = vim.system({
    "tasklist", "/FI", "IMAGENAME eq " .. project_name .. ".exe", "/NH", "/FO", "CSV",
  }, { text = true }):wait()
  if res.code == 0 and res.stdout then
    -- CSV row: "Proj.exe","1234","Console","1","20,000 K"
    local pid = res.stdout:match('^"[^"]*","(%d+)"')
    if pid then return tonumber(pid) end
  end

  local ps = powershell_exe()
  if not ps then return nil end
  local script = string.format(
    "Get-CimInstance Win32_Process -Filter \"Name='dotnet.exe'\""
      .. " | Where-Object { $_.CommandLine -like '*%s.dll*' }"
      .. " | Select-Object -First 1 -ExpandProperty ProcessId",
    project_name
  )
  local out = vim.system(
    { ps, "-NoProfile", "-NonInteractive", "-Command", script }, { text = true }
  ):wait()
  if out.code == 0 and out.stdout then
    return tonumber(out.stdout:match("(%d+)"))
  end
  return nil
end

local function find_pid(project_name)
  if is_win then return find_pid_win(project_name) end

  local dll = vim.system({ "pgrep", "-f", project_name .. "[.]dll" }, { text = true }):wait()
  if dll.code == 0 and dll.stdout and dll.stdout ~= "" then
    return tonumber(dll.stdout:match("(%d+)"))
  end
  local any = vim.system({ "pgrep", "-f", project_name }, { text = true }):wait()
  if any.code == 0 and any.stdout then
    return tonumber(any.stdout:match("(%d+)"))
  end
  return nil
end

-- find_pid blocks on :wait(). pgrep returns in ~5ms, tasklist in ~50-250ms, so
-- Windows polls less often to keep the UI responsive during the wait.
local POLL_MS = is_win and 250 or 100

local function wait_for_pid(project_name, timeout_ms, callback)
  local attempts = 0
  local max_attempts = timeout_ms / POLL_MS
  local timer = vim.uv.new_timer()
  timer:start(POLL_MS, POLL_MS, vim.schedule_wrap(function()
    attempts = attempts + 1
    local pid = find_pid(project_name)
    if pid then
      timer:stop(); timer:close()
      callback(pid)
    elseif attempts >= max_attempts then
      timer:stop(); timer:close()
      callback(nil)
    end
  end))
end

local function attach(pid)
  if not pid then
    vim.notify("Could not find process to attach to", vim.log.levels.ERROR)
    return
  end
  vim.notify("Attaching debugger to PID " .. pid, vim.log.levels.INFO)
  require("dap").run({
    type = "coreclr",
    name = "Attach to Process",
    request = "attach",
    processId = pid,
  })
end

---Open a toggleterm split running `cmd` in `dir`. Replaces any prior terminal.
---`dir` is handed to termopen as cwd, so no `cd &&` prefix is needed — which
---also keeps this shell-agnostic (nvim's default shell on Windows is cmd.exe,
---where a bare `cd` will not cross drive letters).
local function spawn_terminal(dir, cmd)
  local Terminal = require("toggleterm.terminal").Terminal
  if debug_terminal then debug_terminal:shutdown() end
  debug_terminal = Terminal:new({
    cmd = cmd,
    dir = dir,
    direction = "horizontal",
    size = 15,
    close_on_exit = false,
    on_open = function() vim.cmd("startinsert!") end,
  })
  debug_terminal:open()
end

---Run `cmd_str` in a new WezTerm tab. Only possible when nvim is itself running
---inside a WezTerm pane (`wezterm cli` talks to the mux over $WEZTERM_UNIX_SOCKET,
---which only exists there). Returns true on success.
local function spawn_wezterm_tab(dir, cmd_str)
  if not (vim.env.WEZTERM_PANE and vim.env.WEZTERM_PANE ~= "") then return false end
  if vim.fn.executable("wezterm") ~= 1 then return false end

  -- Replace any previous tab, mirroring spawn_terminal's shutdown of the old
  -- toggleterm — otherwise repeated <leader>dd strands one tab per run.
  if debug_pane_id then
    vim.system({ "wezterm", "cli", "kill-pane", "--pane-id", debug_pane_id }):wait()
    debug_pane_id = nil
  end

  -- Keep the tab alive after the app exits so build errors stay readable.
  local shell
  if is_win then
    local ps = powershell_exe()
    if not ps then return false end
    shell = { ps, "-NoLogo", "-NoExit", "-Command", cmd_str }
  else
    shell = { vim.env.SHELL or "bash", "-lc", cmd_str .. "; exec " .. (vim.env.SHELL or "bash") }
  end

  local args = { "wezterm", "cli", "spawn", "--cwd", dir, "--" }
  vim.list_extend(args, shell)

  local r = vim.system(args, { text = true }):wait()
  if r.code ~= 0 then
    vim.notify("wezterm cli spawn failed: " .. (r.stderr or "?"), vim.log.levels.WARN)
    return false
  end
  -- `wezterm cli spawn` prints the new pane id on stdout; remember it so
  -- stop_terminal can close the tab rather than leaving it behind.
  debug_pane_id = r.stdout and r.stdout:match("%d+") or nil
  return true
end

---Spawn `dotnet run` outside nvim where possible — a detached tmux window inside
---tmux, a new WezTerm tab inside WezTerm — falling back to a toggleterm split.
---Attach with <leader>da.
function M.debug_with_terminal()
  local csproj, project_dir = find_csproj()
  if not csproj then
    vim.notify("No .csproj found", vim.log.levels.ERROR)
    return
  end
  local name = project_name_of(csproj)

  if vim.env.TMUX and vim.env.TMUX ~= "" then
    vim.notify("Building and running " .. name .. " (tmux window 'dotnet-run')", vim.log.levels.INFO)
    local r = vim.fn.system({
      "tmux", "new-window", "-d",
      "-n", "dotnet-run",
      "-c", project_dir,
      "dotnet run; exec bash",
    })
    if vim.v.shell_error ~= 0 then
      vim.notify("tmux new-window failed: " .. r, vim.log.levels.ERROR)
      return
    end
    vim.notify("Attach with <leader>da when the app is up.", vim.log.levels.INFO)
    return
  end

  if spawn_wezterm_tab(project_dir, "dotnet run") then
    vim.notify(
      "Running " .. name .. " in a new WezTerm tab. Attach with <leader>da when the app is up.",
      vim.log.levels.INFO
    )
    return
  end

  -- Fallback: toggleterm split
  vim.notify("Running " .. name .. " in a split. Attach with <leader>da.", vim.log.levels.INFO)
  spawn_terminal(project_dir, "dotnet run")
end

---Azure Functions isolated-worker debug. `func start --dotnet-isolated-debug`
---makes the worker pause until netcoredbg attaches → deterministic BP binding.
function M.debug_func()
  local csproj, project_dir = find_csproj()
  if not csproj then
    vim.notify("No .csproj found", vim.log.levels.ERROR)
    return
  end
  local name = project_name_of(csproj)
  vim.notify("func start: " .. name, vim.log.levels.INFO)

  spawn_terminal(project_dir, "dotnet build && func start --dotnet-isolated-debug --no-build")

  -- Isolated worker process matches "<Project>.dll"
  wait_for_pid(name, 30000, function(pid)
    if pid then
      vim.defer_fn(function()
        vim.cmd("wincmd k")
        attach(pid)
      end, 500)
    else
      vim.notify("Timeout waiting for func worker. Attach manually with <leader>da.", vim.log.levels.WARN)
    end
  end)
end

---Just build + run in the terminal. No auto-attach (use <leader>da later if you want).
function M.run_in_terminal()
  local csproj, project_dir = find_csproj()
  if not csproj then
    vim.notify("No .csproj found", vim.log.levels.ERROR)
    return
  end
  local name = project_name_of(csproj)
  vim.notify("Running " .. name .. " (attach with <leader>da)")

  spawn_terminal(project_dir, "dotnet build && dotnet run --no-build")
end

---Try to find the dotnet process for the current project; fall back to pick_process.
function M.attach_to_dotnet()
  local csproj = find_csproj()
  if csproj then
    local pid = find_pid(project_name_of(csproj))
    if pid then return attach(pid) end
  end
  require("dap").run({
    type = "coreclr",
    name = "Attach",
    request = "attach",
    processId = require("dap.utils").pick_process,
  })
end

function M.toggle_terminal()
  if debug_terminal then
    debug_terminal:toggle()
  else
    vim.notify("No debug terminal active. Start with <leader>dd first.", vim.log.levels.WARN)
  end
end

---Everything that has to happen once the debug adapter is out of the way.
local function stop_cleanup()
  pcall(function() require("dapui").close() end)
  -- Kill the app itself. When it runs in a tmux window or WezTerm tab, shutting
  -- down the toggleterm buffer reaps nothing — the port would stay bound.
  local csproj = find_csproj()
  if csproj then
    local pid = find_pid(project_name_of(csproj))
    if pid then
      if is_win then
        vim.system({ "taskkill", "/PID", tostring(pid), "/T", "/F" }):wait()
      else
        vim.system({ "kill", tostring(pid) }):wait()
      end
    end
  end

  if debug_terminal then
    debug_terminal:shutdown()
    debug_terminal = nil
  end
  -- Close the WezTerm tab too. Killing the app above leaves the pane alive,
  -- because it runs under `pwsh -NoExit` / `exec $SHELL` so build output
  -- survives the app exiting — only an explicit stop should close it.
  if debug_pane_id then
    vim.system({ "wezterm", "cli", "kill-pane", "--pane-id", debug_pane_id }):wait()
    debug_pane_id = nil
  end
  if not is_win then
    vim.fn.system({ "tmux", "kill-window", "-t", "dotnet-run" })
  end
  vim.notify("Debug stopped", vim.log.levels.INFO)
end

function M.stop_terminal()
  local ok, dap = pcall(require, "dap")

  -- Only ever run the cleanup once: on_done and the timeout below can both fire.
  local done = false
  local function once()
    if done then return end
    done = true
    stop_cleanup()
  end

  if not (ok and dap.session()) then
    once()
    return
  end

  -- Wait for the adapter to finish terminating before tearing anything down.
  --
  -- This used to be `dap.terminate()` immediately followed by `dap.close()`.
  -- close() calls session:close() straight away, which yanked netcoredbg's stdio
  -- while the `terminate` request was still in flight: the adapter died with
  -- exit code 1, and dap/session.lua notifies on any non-zero adapter exit —
  -- that was the "exited with 1" popup. The reply then never arrived, so the
  -- request also hit nvim-dap's 3s timeout and logged a warning.
  -- terminate() closes the session itself, so close() is not needed at all.
  local scheduled = vim.schedule_wrap(once)
  if not pcall(function() dap.terminate({ on_done = scheduled }) end) then
    once()
    return
  end

  -- Safety net: adapters that ignore terminate fall back to disconnect, and
  -- either can hang. 4s clears nvim-dap's 3s request timeout.
  vim.defer_fn(once, 4000)
end

return M
