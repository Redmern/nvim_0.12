-- trouble.nvim — pretty diagnostics / quickfix / lsp-refs browser.
require("trouble").setup({})

local function open(mode) return function() require("trouble").toggle(mode) end end
vim.keymap.set("n", "<leader>xx", open("diagnostics"),         { desc = "Diagnostics (Trouble)" })
vim.keymap.set("n", "<leader>xX", open("diagnostics buf=0"),   { desc = "Buffer diagnostics" })
vim.keymap.set("n", "<leader>xs", open("symbols"),             { desc = "Symbols (Trouble)" })
vim.keymap.set("n", "<leader>xL", open("loclist"),             { desc = "Location list" })
vim.keymap.set("n", "<leader>xq", open("qflist"),              { desc = "Quickfix list" })
vim.keymap.set("n", "gR",         open("lsp_references"),      { desc = "LSP references (Trouble)" })

require("which-key").add({ { "<leader>x", group = "Trouble", icon = { icon = "󰒡", color = "red" } } })
