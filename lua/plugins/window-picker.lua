-- Letter-pick windows. Used implicitly by neo-tree's "open in window..."
-- prompt; the letter overlay appears when more than one target exists.
require("window-picker").setup({
    hint = "floating-big-letter",
    filter_rules = {
        autoselect_one = true,
        include_current_win = false,
        bo = {
            filetype = { "neo-tree", "neo-tree-popup", "notify" },
            buftype  = { "terminal", "quickfix" },
        },
    },
})

vim.keymap.set("n", "<leader>w", function()
    local win = require("window-picker").pick_window()
    if win then vim.api.nvim_set_current_win(win) end
end, { desc = "Pick window" })
