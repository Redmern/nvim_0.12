-- Build + run + auto-attach workflow for .NET projects (Blazor Server, console, ASP.NET).
-- Uses a visible toggleterm split so Console.ReadKey / ReadLine work normally.
-- The tmux path just runs `dotnet run` (no DOTNET_EnableDiagnostics set); on
-- Linux netcoredbg can attach to the running process by PID regardless.
local M = {}

local debug_terminal = nil

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
local function find_pid(project_name)
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

local function wait_for_pid(project_name, timeout_ms, callback)
  local attempts = 0
  local max_attempts = timeout_ms / 100
  local timer = vim.uv.new_timer()
  timer:start(100, 100, vim.schedule_wrap(function()
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

---Spawn `dotnet run` in a detached tmux window (requires being inside tmux).
---Falls back to a toggleterm split if not inside tmux. Attach with <leader>da.
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

  -- Fallback: toggleterm split
  vim.notify("Not in tmux — running " .. name .. " in a split. Attach with <leader>da.", vim.log.levels.INFO)
  local Terminal = require("toggleterm.terminal").Terminal
  if debug_terminal then debug_terminal:shutdown() end
  debug_terminal = Terminal:new({
    cmd = "cd " .. vim.fn.shellescape(project_dir) .. " && dotnet run",
    dir = project_dir,
    direction = "horizontal",
    size = 15,
    close_on_exit = false,
    on_open = function() vim.cmd("startinsert!") end,
  })
  debug_terminal:open()
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

  local Terminal = require("toggleterm.terminal").Terminal
  if debug_terminal then debug_terminal:shutdown() end

  local run_cmd = "cd " .. vim.fn.shellescape(project_dir)
    .. " && dotnet build"
    .. " && func start --dotnet-isolated-debug --no-build"

  debug_terminal = Terminal:new({
    cmd = run_cmd,
    dir = project_dir,
    direction = "horizontal",
    size = 15,
    close_on_exit = false,
    on_open = function() vim.cmd("startinsert!") end,
  })
  debug_terminal:open()

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

  local Terminal = require("toggleterm.terminal").Terminal
  if debug_terminal then debug_terminal:shutdown() end

  debug_terminal = Terminal:new({
    cmd = "cd " .. vim.fn.shellescape(project_dir) .. " && dotnet build && dotnet run --no-build",
    dir = project_dir,
    direction = "horizontal",
    size = 15,
    close_on_exit = false,
    on_open = function() vim.cmd("startinsert!") end,
  })
  debug_terminal:open()
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

function M.stop_terminal()
  pcall(function() require("dap").terminate() end)
  pcall(function() require("dap").close() end)
  pcall(function() require("dapui").close() end)
  if debug_terminal then
    debug_terminal:shutdown()
    debug_terminal = nil
  end
  vim.fn.system({ "tmux", "kill-window", "-t", "dotnet-run" })
  vim.notify("Debug stopped", vim.log.levels.INFO)
end

return M
