-- Persist every error message to disk. Errors that follow each other within
-- GAP seconds land in the same file (one burst = one file); a quiet gap starts
-- a new one. Fed by the noice route in plugins/noice.lua, so it sees
-- vim.notify(ERROR) as well as emsg / echoerr / lua_error / rpc_error.
local M = {}

M.dir = vim.fs.joinpath(vim.fn.stdpath("log"), "errors")
M.gap = 60 -- seconds of silence before a new file is started

local current_file, last_time
local seen = {} -- message id -> last logged text (noice re-routes on update)

local function newest_file()
    local newest, newest_mtime
    for name, type in vim.fs.dir(M.dir) do
        if type == "file" and name:match("%.log$") then
            local path = vim.fs.joinpath(M.dir, name)
            local stat = vim.uv.fs_stat(path)
            if stat and (not newest_mtime or stat.mtime.sec > newest_mtime) then
                newest, newest_mtime = path, stat.mtime.sec
            end
        end
    end
    return newest, newest_mtime
end

local function target_file(now)
    if current_file and last_time and now - last_time <= M.gap then
        return current_file
    end
    -- Continue a burst across a restart (e.g. an error on every startup).
    local newest, mtime = newest_file()
    if newest and now - mtime <= M.gap then
        return newest
    end
    return vim.fs.joinpath(M.dir, os.date("%Y-%m-%d_%H-%M-%S", now) .. ".log")
end

---@param text string
---@param source? string
function M.write(text, source)
    if text == "" then
        return
    end
    vim.fn.mkdir(M.dir, "p")
    local now = os.time()
    current_file = target_file(now)
    last_time = now

    local fd = io.open(current_file, "a")
    if not fd then
        return
    end
    fd:write(("[%s] pid=%d %s\n%s\n\n"):format(os.date("%H:%M:%S", now), vim.fn.getpid(), source or "", text))
    fd:close()
end

--- noice filter `cond`: logs the message as a side effect, never matches.
---@param message NoiceMessage
function M.noice_cond(message)
    if message.level == "error" then
        local text = message:content()
        if seen[message.id] ~= text then
            seen[message.id] = text
            local source = message.event .. ((message.kind or "") ~= "" and (":" .. message.kind) or "")
            pcall(M.write, text, source)
        end
    end
    return false
end

vim.api.nvim_create_user_command("ErrorLog", function(opts)
    if opts.bang then
        return vim.cmd.edit(vim.fn.fnameescape(M.dir))
    end
    local newest = vim.fn.isdirectory(M.dir) == 1 and newest_file()
    if not newest then
        return vim.notify("No errors logged in " .. M.dir, vim.log.levels.INFO)
    end
    vim.cmd.edit(vim.fn.fnameescape(newest))
end, { bang = true, desc = "Open the latest error log (! = the errors folder)" })

return M
