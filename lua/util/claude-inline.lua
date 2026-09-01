-- Inline Claude edit: visually select code, <leader>ca (see config/keymaps.lua),
-- type an instruction in a small floating input, and the selection is replaced
-- by Claude's rewrite. While the request runs, animated spinner lines sit
-- above and below the selection; both are extmarks, so edits elsewhere in the
-- buffer shift them (and the tracked replace range) correctly.
--
-- Backend is the installed `claude` CLI in headless print mode (`claude -p`
-- reading the prompt from stdin), so it reuses the normal Claude Code auth —
-- no API keys anywhere in this config. One request per buffer at a time.
local M = {}

local ns = vim.api.nvim_create_namespace("claude_inline")
local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local TIMEOUT_MS = 120000

local busy = {} -- buf -> true while a request is in flight

-- ---------------------------------------------------------------------------
-- Spinner: two virt_lines extmarks bracketing the selection. Returned handle
-- carries the extmark ids (used later to recover the tracked line range) and
-- a stop() that kills the animation timer and removes the marks.
-- ---------------------------------------------------------------------------
local function start_spinner(buf, top_row, bot_row)
    local function spin_line(frame)
        return { { ("  %s  Claude is editing…"):format(SPINNER[frame]), "DiagnosticInfo" } }
    end

    local above = vim.api.nvim_buf_set_extmark(buf, ns, top_row, 0, {
        virt_lines = { spin_line(1) },
        virt_lines_above = true,
    })
    local below = vim.api.nvim_buf_set_extmark(buf, ns, bot_row, 0, {
        virt_lines = { spin_line(1) },
    })

    local frame = 1
    local timer = vim.uv.new_timer()
    timer:start(0, 100, vim.schedule_wrap(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        frame = frame % #SPINNER + 1
        for id, is_above in pairs({ [above] = true, [below] = false }) do
            local pos = vim.api.nvim_buf_get_extmark_by_id(buf, ns, id, {})
            if pos[1] then
                pcall(vim.api.nvim_buf_set_extmark, buf, ns, pos[1], 0, {
                    id = id,
                    virt_lines = { spin_line(frame) },
                    virt_lines_above = is_above,
                })
            end
        end
    end))

    return {
        above = above,
        below = below,
        stop = function()
            timer:stop()
            timer:close()
            if vim.api.nvim_buf_is_valid(buf) then
                pcall(vim.api.nvim_buf_del_extmark, buf, ns, above)
                pcall(vim.api.nvim_buf_del_extmark, buf, ns, below)
            end
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Response cleanup: models like wrapping code in ``` fences despite being told
-- not to — strip one outer fence pair if present, keep everything else as-is.
-- ---------------------------------------------------------------------------
local function to_lines(stdout)
    local lines = vim.split(stdout:gsub("\r\n", "\n"):gsub("\n+$", ""), "\n")
    if #lines >= 2 and lines[1]:match("^```") and lines[#lines]:match("^```%s*$") then
        table.remove(lines, #lines)
        table.remove(lines, 1)
    end
    return lines
end

local function run(buf, top_row, bot_row, instruction)
    busy[buf] = true
    local spinner = start_spinner(buf, top_row, bot_row)
    local code = table.concat(vim.api.nvim_buf_get_lines(buf, top_row, bot_row + 1, false), "\n")

    local prompt = table.concat({
        "You are performing an inline edit inside a code editor.",
        "File: " .. (vim.api.nvim_buf_get_name(buf) ~= "" and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t") or "untitled"),
        "Language: " .. (vim.bo[buf].filetype ~= "" and vim.bo[buf].filetype or "plain text"),
        "",
        "Instruction: " .. instruction,
        "",
        "Apply the instruction to the code below. Return ONLY the replacement",
        "code: no markdown fences, no commentary, and keep the original",
        "indentation style of the snippet.",
        "",
        code,
    }, "\n")

    vim.system(
        { "claude", "-p" },
        { stdin = prompt, text = true, timeout = TIMEOUT_MS },
        vim.schedule_wrap(function(result)
            busy[buf] = nil
            if not vim.api.nvim_buf_is_valid(buf) then
                spinner.stop()
                return
            end
            -- recover the (possibly shifted) range from the spinner extmarks
            -- BEFORE stop() deletes them
            local top = vim.api.nvim_buf_get_extmark_by_id(buf, ns, spinner.above, {})
            local bot = vim.api.nvim_buf_get_extmark_by_id(buf, ns, spinner.below, {})
            spinner.stop()

            if result.code ~= 0 then
                local reason = result.code == 124 and "timed out after " .. TIMEOUT_MS / 1000 .. "s"
                    or vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr)
                    or ("exited with code " .. result.code)
                vim.notify("Claude inline edit failed: " .. reason, vim.log.levels.ERROR)
                return
            end
            local lines = to_lines(result.stdout or "")
            if #lines == 0 or not top[1] or not bot[1] then
                vim.notify("Claude inline edit: empty response", vim.log.levels.WARN)
                return
            end
            vim.api.nvim_buf_set_lines(buf, top[1], bot[1] + 1, false, lines)
            vim.notify(("Claude inline edit applied (%d → %d lines)"):format(bot[1] - top[1] + 1, #lines))
        end)
    )
end

-- ---------------------------------------------------------------------------
-- Floating single-line input. <CR> submits, <Esc> cancels. Deliberately a
-- plain scratch buffer (not vim.ui.input): keeps behavior identical whether
-- or not noice/nui decide to redecorate ui.input.
-- ---------------------------------------------------------------------------
local function open_input(on_submit)
    local ibuf = vim.api.nvim_create_buf(false, true)
    vim.bo[ibuf].bufhidden = "wipe"
    local width = math.min(70, math.max(40, vim.o.columns - 20))
    local win = vim.api.nvim_open_win(ibuf, true, {
        relative = "cursor",
        row = 1,
        col = 0,
        width = width,
        height = 1,
        style = "minimal",
        border = "rounded",
        title = " Claude edit — describe the change ",
        title_pos = "center",
    })

    local function close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    vim.keymap.set({ "i", "n" }, "<CR>", function()
        local text = vim.trim(vim.api.nvim_buf_get_lines(ibuf, 0, 1, false)[1] or "")
        close()
        vim.cmd.stopinsert()
        if text ~= "" then
            on_submit(text)
        end
    end, { buffer = ibuf })
    vim.keymap.set({ "i", "n" }, "<Esc>", function()
        close()
        vim.cmd.stopinsert()
    end, { buffer = ibuf })

    vim.cmd.startinsert()
end

-- Entry point for the visual-mode keymap. Reads the selection while visual
-- mode is still active (line("v")/line(".")), then leaves visual mode so the
-- input float gets normal editing.
function M.ask()
    local buf = vim.api.nvim_get_current_buf()
    if busy[buf] then
        vim.notify("Claude inline edit already running in this buffer", vim.log.levels.WARN)
        return
    end
    local l1, l2 = vim.fn.line("v"), vim.fn.line(".")
    if l1 > l2 then
        l1, l2 = l2, l1
    end
    -- "nx": execute immediately (not queued typeahead), unmapped — the queued
    -- form would land the Esc inside the input float we open next
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    open_input(function(instruction)
        run(buf, l1 - 1, l2 - 1, instruction)
    end)
end

return M
