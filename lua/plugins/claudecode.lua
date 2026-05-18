require("claudecode").setup({
  terminal = {
    show_native_term_exit_tip = false,
  },
})

-- <leader>c* — Claude Code
vim.keymap.set({ "n", "t" }, "<leader>cc", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude Code" })
vim.keymap.set("n", "<leader>cf", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude Code" })
vim.keymap.set("v", "<leader>cs", "<cmd>ClaudeCodeSend<cr>", { desc = "Send selection to Claude" })
vim.keymap.set("n", "<leader>ca", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add current file to context" })
