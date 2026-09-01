vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>")

vim.keymap.set("x", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("x", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

vim.keymap.set("x", ">", ">gv", { desc = "Indent and keep selection" })
vim.keymap.set("x", "<", "<gv", { desc = "Dedent and keep selection" })

-- Visual-mode only; normal-mode <leader>ca (ClaudeCodeAdd) lives in plugins/claudecode.lua
vim.keymap.set("x", "<leader>ca", function()
    require("util.claude-inline").ask()
end, { desc = "Claude: edit selection inline" })

vim.keymap.set("n", "<leader>nn", function()
    require("util.weekly-notes").open_current()
end, { desc = "Notes: open this week" })
vim.keymap.set("n", "<leader>nN", function()
    require("util.weekly-notes").open_offset(1)
end, { desc = "Notes: open next week" })
vim.keymap.set("n", "<leader>np", function()
    require("util.weekly-notes").open_offset(-1)
end, { desc = "Notes: open previous week" })

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(ev)
        local md = require("util.markdown")
        local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
        end

        -- editing helpers (util.markdown)
        map("n", "tt", "o- [ ] ", "New checkbox item")
        map({ "n", "x" }, "<leader>mx", md.toggle_checkbox, "Markdown: toggle checkbox")
        map("n", "<leader>mo", md.toc, "Markdown: outline / TOC")
        map("n", "<leader>mt", md.format_table, "Markdown: reflow / align tables (prettier)")
        map("x", "<leader>ml", md.paste_url_link, "Markdown: wrap selection as link (clipboard URL)")

        -- follow / navigate links ([[wiki]], [text](file.md), http)
        map("n", "<CR>", md.follow_link, "Markdown: follow link under cursor")
        map("n", "gf", md.follow_link, "Markdown: follow link under cursor")
        map("n", "<BS>", "<C-o>", "Markdown: jump back")

        -- heading navigation
        map("n", "]]", md.next_heading, "Markdown: next heading")
        map("n", "[[", md.prev_heading, "Markdown: previous heading")

        -- list continuation (autolist) — buffer-local so global <CR>/o/O and
        -- blink's insert <Tab> are untouched outside markdown
        map("i", "<CR>", "<CR><cmd>AutolistNewBullet<cr>", "New list item")
        map("n", "o", "o<cmd>AutolistNewBullet<cr>", "New list item below")
        map("n", "O", "O<cmd>AutolistNewBulletBefore<cr>", "New list item above")
        map("i", "<C-t>", "<C-t><cmd>AutolistRecalculate<cr>", "Indent list item")
        map("i", "<C-d>", "<C-d><cmd>AutolistRecalculate<cr>", "Dedent list item")
        map("n", ">>", ">><cmd>AutolistRecalculate<cr>", "Indent list item")
        map("n", "<<", "<<<cmd>AutolistRecalculate<cr>", "Dedent list item")
        map("n", "dd", "dd<cmd>AutolistRecalculate<cr>", "Delete line (renumber list)")
        map("n", "<leader>mr", "<cmd>AutolistRecalculate<cr>", "Markdown: renumber list")
        map("n", "<leader>mc", require("autolist").cycle_next_dr, "Markdown: cycle list marker")

        -- fold by heading (treesitter); start unfolded
        vim.wo.foldmethod = "expr"
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldlevel = 99
    end,
})
