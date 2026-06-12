vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>")

vim.keymap.set("x", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("x", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

vim.keymap.set("x", ">", ">gv", { desc = "Indent and keep selection" })
vim.keymap.set("x", "<", "<gv", { desc = "Dedent and keep selection" })

vim.keymap.set("n", "<leader>nn", function() require("util.weekly-notes").open_current() end,   { desc = "Notes: open this week" })
vim.keymap.set("n", "<leader>nN", function() require("util.weekly-notes").open_offset(1) end,   { desc = "Notes: open next week" })
vim.keymap.set("n", "<leader>np", function() require("util.weekly-notes").open_offset(-1) end,  { desc = "Notes: open previous week" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(ev)
    vim.keymap.set("n", "tt", "o- [ ] ", { buffer = ev.buf, desc = "New checkbox item" })
  end,
})
