-- Small markdown editing helpers, wired to <leader>m* for markdown buffers in
-- lua/config/keymaps.lua. No plugin — just buffer text manipulation.
local M = {}

-- Toggle `- [ ]` <-> `- [x]` on the given 1-indexed line. Adds `[ ]` to a bare
-- `- ` bullet; leaves non-list lines alone. Returns true if it changed anything.
local function toggle_line(lnum)
    local line = vim.fn.getline(lnum)
    local new
    if line:match("^(%s*[-*+] )%[[ ]%]") then
        new = line:gsub("(%s*[-*+] )%[[ ]%]", "%1[x]", 1)
    elseif line:match("^(%s*[-*+] )%[[xX]%]") then
        new = line:gsub("(%s*[-*+] )%[[xX]%]", "%1[ ]", 1)
    elseif line:match("^(%s*[-*+] )") then
        new = line:gsub("^(%s*[-*+] )", "%1[ ] ", 1)
    else
        return false
    end
    vim.fn.setline(lnum, new)
    return true
end

-- Normal mode: current line. Visual mode: every line in the selection.
function M.toggle_checkbox()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
        local s = vim.fn.line("v")
        local e = vim.fn.line(".")
        if s > e then
            s, e = e, s
        end
        for l = s, e do
            toggle_line(l)
        end
        vim.api.nvim_input("<Esc>")
    else
        toggle_line(vim.fn.line("."))
    end
end

-- Jump to a heading via vim.ui.select. Indented by heading depth.
function M.toc()
    local items = {}
    for lnum, text in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        local hashes, title = text:match("^(#+)%s+(.+)$")
        if hashes and not text:match("^#+%s*$") then
            table.insert(items, {
                lnum = lnum,
                label = ("  "):rep(#hashes - 1) .. title,
            })
        end
    end
    if #items == 0 then
        vim.notify("No headings", vim.log.levels.INFO)
        return
    end
    vim.ui.select(items, {
        prompt = "TOC",
        format_item = function(it)
            return it.label
        end,
    }, function(choice)
        if choice then
            vim.api.nvim_win_set_cursor(0, { choice.lnum, 0 })
            vim.cmd("normal! zz")
        end
    end)
end

-- Reflow markdown through prettier (conform): pads/aligns every pipe-table,
-- normalises list markers, rewraps. prettier has no range mode, so this is a
-- whole-buffer format — same as <leader>lf, kept under <leader>mt as the
-- table-fixing muscle-memory key.
function M.format_table()
    require("conform").format({ bufnr = 0, lsp_fallback = true })
end

return M
