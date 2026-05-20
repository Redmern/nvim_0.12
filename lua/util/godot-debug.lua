-- Build + run + auto-attach workflow for Godot 4 C# (Mono / .NET) projects.
-- Mirrors lua/util/dotnet-debug.lua but for godot-mono.
--
-- The Godot game runs inside the godot-mono process which embeds .NET, so
-- netcoredbg can attach to it via PID exactly the same way as a `dotnet run`
-- process. We launch in a toggleterm split so GD.Print output stays visible.
local M = {}

local debug_terminal = nil

local function find_godot_project()
    local buf_path = vim.api.nvim_buf_get_name(0)
    local start = buf_path ~= "" and vim.fn.fnamemodify(buf_path, ":p:h") or vim.fn.getcwd()

    local found = vim.fs.find("project.godot", {
        upward = true,
        path = start,
        type = "file",
        limit = 1,
    })
    if found and found[1] then
        return found[1], vim.fn.fnamemodify(found[1], ":h")
    end

    local cwd = vim.fn.getcwd()
    if vim.fn.filereadable(cwd .. "/project.godot") == 1 then
        return cwd .. "/project.godot", cwd
    end
    return nil, nil
end

---Prefer a .sln (which references Domain + Tests), fall back to the Godot
---.csproj. Returns an absolute path or nil. Without this `dotnet build` in
---a folder containing both Game.csproj and Game.sln refuses with MSB1011.
local function find_build_target(project_dir)
    local sln = vim.fn.glob(project_dir .. "/*.sln", false, true)
    if #sln > 0 then return sln[1] end

    local csproj = vim.fn.glob(project_dir .. "/*.csproj", false, true)
    if #csproj > 0 then return csproj[1] end

    return nil
end

local function build_cmd(project_dir)
    local target = find_build_target(project_dir)
    if not target then return "dotnet build" end
    return "dotnet build " .. vim.fn.shellescape(target)
end

---Find the godot-mono pid for *this* project. Match by --path argument or
---by the project dir appearing in cmdline — avoids grabbing the Godot editor
---if it's open against a different project.
local function find_pid(project_dir)
    local res = vim.system({ "pgrep", "-af", "godot[-_]?mono" }, { text = true }):wait()
    if res.code ~= 0 or not res.stdout or res.stdout == "" then return nil end

    for line in res.stdout:gmatch("[^\n]+") do
        local pid, cmd = line:match("^(%d+)%s+(.+)$")
        if pid and cmd then
            -- Skip the editor (--editor / -e). We want the running game.
            local is_editor = cmd:match("%-%-editor") or cmd:match(" %-e ") or cmd:match(" %-e$")
            local matches_project = cmd:find(project_dir, 1, true) ~= nil
            if matches_project and not is_editor then
                return tonumber(pid)
            end
        end
    end

    -- Fallback: any godot-mono that isn't the editor
    for line in res.stdout:gmatch("[^\n]+") do
        local pid, cmd = line:match("^(%d+)%s+(.+)$")
        if pid and cmd and not (cmd:match("%-%-editor") or cmd:match(" %-e ")) then
            return tonumber(pid)
        end
    end

    return nil
end

local function wait_for_pid(project_dir, timeout_ms, callback)
    local attempts, max_attempts = 0, timeout_ms / 100
    local timer = vim.uv.new_timer()
    timer:start(100, 100, vim.schedule_wrap(function()
        attempts = attempts + 1
        local pid = find_pid(project_dir)
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
        vim.notify("Could not find godot-mono process to attach to", vim.log.levels.ERROR)
        return
    end
    vim.notify("Attaching debugger to godot-mono PID " .. pid, vim.log.levels.INFO)
    require("dap").run({
        type = "coreclr",
        name = "Attach to Godot",
        request = "attach",
        processId = pid,
    })
end

---Open a toggleterm split running `cmd` in `dir`. Replaces any prior terminal.
local function spawn_terminal(dir, cmd)
    local Terminal = require("toggleterm.terminal").Terminal
    if debug_terminal then debug_terminal:shutdown() end
    debug_terminal = Terminal:new({
        cmd = "cd " .. vim.fn.shellescape(dir) .. " && " .. cmd,
        dir = dir,
        direction = "horizontal",
        size = 15,
        close_on_exit = false,
        on_open = function() vim.cmd("startinsert!") end,
    })
    debug_terminal:open()
end

---Run the Godot game (no debugger attach).
function M.run_game()
    local proj, dir = find_godot_project()
    if not proj then
        vim.notify("No project.godot found upward from current buffer", vim.log.levels.ERROR)
        return
    end
    vim.notify("Running Godot: " .. dir, vim.log.levels.INFO)
    spawn_terminal(dir, build_cmd(dir) .. " && godot-mono --path " .. vim.fn.shellescape(dir))
end

---Build + run + auto-attach netcoredbg once godot-mono starts.
function M.debug_game()
    local proj, dir = find_godot_project()
    if not proj then
        vim.notify("No project.godot found upward from current buffer", vim.log.levels.ERROR)
        return
    end
    vim.notify("Debug Godot: " .. dir .. " (auto-attach on launch)", vim.log.levels.INFO)

    -- DOTNET_EnableDiagnostics=1 ensures the diagnostics port is open even
    -- if release-flavoured runtime defaults try to suppress it.
    local launch = "DOTNET_EnableDiagnostics=1 " .. build_cmd(dir)
        .. " && DOTNET_EnableDiagnostics=1 godot-mono --path " .. vim.fn.shellescape(dir)
    spawn_terminal(dir, launch)

    wait_for_pid(dir, 30000, function(pid)
        if pid then
            vim.defer_fn(function()
                vim.cmd("wincmd k") -- focus back to the code window above the term
                attach(pid)
            end, 500)
        else
            vim.notify("Timeout waiting for godot-mono. Attach manually with <leader>Ga.",
                vim.log.levels.WARN)
        end
    end)
end

---Attach to a godot-mono process that's already running.
function M.attach_to_godot()
    local _, dir = find_godot_project()
    if dir then
        local pid = find_pid(dir)
        if pid then return attach(pid) end
    end
    require("dap").run({
        type = "coreclr",
        name = "Attach (pick process)",
        request = "attach",
        processId = require("dap.utils").pick_process,
    })
end

---Launch the Godot editor for this project (use F5 inside it to play).
function M.open_editor()
    local _, dir = find_godot_project()
    if not dir then
        vim.notify("No project.godot found", vim.log.levels.ERROR)
        return
    end
    vim.system({ "godot-mono", "-e", "--path", dir }, { detach = true })
    vim.notify("Launched Godot editor: " .. dir, vim.log.levels.INFO)
end

---`dotnet build` in a terminal split (no Godot launch).
function M.build()
    local _, dir = find_godot_project()
    if not dir then
        vim.notify("No project.godot found", vim.log.levels.ERROR)
        return
    end
    spawn_terminal(dir, build_cmd(dir))
end

---Re-import Godot assets (run after dropping new files into Assets/).
function M.import_assets()
    local _, dir = find_godot_project()
    if not dir then
        vim.notify("No project.godot found", vim.log.levels.ERROR)
        return
    end
    spawn_terminal(dir, "godot-mono --headless --import")
end

function M.toggle_terminal()
    if debug_terminal then
        debug_terminal:toggle()
    else
        vim.notify("No Godot terminal active. Start with <leader>Gr or <leader>Gd first.",
            vim.log.levels.WARN)
    end
end

function M.stop()
    pcall(function() require("dap").terminate() end)
    pcall(function() require("dap").close() end)
    pcall(function() require("dapui").close() end)

    -- Kill any running godot-mono for this project (graceful).
    local _, dir = find_godot_project()
    if dir then
        local pid = find_pid(dir)
        if pid then vim.system({ "kill", tostring(pid) }) end
    end

    if debug_terminal then
        debug_terminal:shutdown()
        debug_terminal = nil
    end
    vim.notify("Godot debug stopped", vim.log.levels.INFO)
end

return M
