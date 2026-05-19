-- Per-cwd session save/restore. Sessions are tied to the working directory
-- you launched nvim in; switching projects gives you a clean slate.
require("persistence").setup({
    options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" },
})

vim.keymap.set("n", "<leader>qs", function() require("persistence").load() end,
    { desc = "Restore session" })
vim.keymap.set("n", "<leader>qS", function() require("persistence").select() end,
    { desc = "Pick session" })
vim.keymap.set("n", "<leader>ql", function() require("persistence").load({ last = true }) end,
    { desc = "Restore last session" })
vim.keymap.set("n", "<leader>qd", function() require("persistence").stop() end,
    { desc = "Don't save on exit" })

require("which-key").add({ { "<leader>q", group = "Session", icon = { icon = "󰆔", color = "azure" } } })
