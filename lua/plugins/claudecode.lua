require("claudecode").setup({
  terminal = {
    show_native_term_exit_tip = false,
  },
})

-- <leader>c* — Claude Code (icons attached via which-key.add below)
vim.keymap.set({ "n", "t" }, "<leader>cc", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude Code" })
vim.keymap.set("n", "<leader>cf", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude Code" })
vim.keymap.set("v", "<leader>s", "<cmd>ClaudeCodeSend<cr>", { desc = "Send selection to Claude" })
vim.keymap.set("n", "<leader>ca", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add current file to context" })

-- Pin every narrow terminal split (claudecode/opencode side panels).
-- Fired on multiple events because claudecode opens via snacks.terminal which
-- doesn't always trigger TermOpen at a useful time.
local function pin_narrow_term(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then return end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "terminal" then return end
  if vim.api.nvim_win_get_width(win) < math.floor(vim.o.columns * 0.8) then
    vim.wo[win].winfixwidth = true
  end
end

vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter", "WinEnter" }, {
  callback = function() pin_narrow_term(vim.api.nvim_get_current_win()) end,
})

require("which-key").add({
  { "<leader>cc", icon = { icon = "󰭹", color = "purple" }, mode = { "n", "t" } },
  { "<leader>cf", icon = { icon = "󰈶", color = "purple" } },
  { "<leader>ca", icon = { icon = "󰐕", color = "green" } },
  { "<leader>s", icon = { icon = "󰒡", color = "blue" }, mode = "v" },
})
