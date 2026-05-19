require("oil").setup({
  default_file_explorer = false,
  view_options = { show_hidden = true },
  float = {
    border = "rounded",
    max_width = 0.5,
    max_height = 0.7,
    padding = 2,
  },
  keymaps = {
    ["q"] = { "actions.close", mode = "n" },
  }
})

vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })

vim.keymap.set("n", "<leader>E", "<cmd>Oil --float<cr>", { desc = "Toggle oil" })

-- vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "Open file explorer" })
