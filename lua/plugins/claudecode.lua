require("claudecode").setup({
  -- Route to the right account by folder: the wrapper picks CLAUDE_CONFIG_DIR
  -- from the working directory (~/work -> work account, else personal).
  terminal_cmd = vim.fn.expand("$HOME/.local/bin/claude-profile"),
  -- Spawn Claude in nvim's project cwd so the wrapper sees the right folder.
  cwd_provider = function(ctx)
    return ctx.cwd
  end,
  terminal = {
    show_native_term_exit_tip = false,
    -- pin the split geometry so it never depends on which window happens to
    -- be focused when the terminal opens
    split_side = "right",
    split_width_percentage = 0.30,
  },
})

-- Toggling Claude while focus sits in neo-tree (or another side panel) makes
-- the split land relative to the wrong window — sometimes consuming the
-- tree, sometimes opening a sliver. Always jump to the main editor window
-- first, then re-assert the tree's width once the split has landed.
local function main_window()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.api.nvim_win_get_config(w).relative == ""
        and vim.bo[b].buftype == ""
        and vim.bo[b].filetype ~= "neo-tree"
        and not vim.w[w].statusline_pad then
      return w
    end
  end
end

local function claude_toggle()
  -- toggling from inside the claude terminal itself just closes it
  if vim.bo.buftype ~= "terminal" then
    local main = main_window()
    if main then vim.api.nvim_set_current_win(main) end
  end
  vim.cmd("ClaudeCode")
  vim.defer_fn(function()
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree" then
        vim.api.nvim_win_set_width(w, 45)
        vim.wo[w].winfixwidth = true
      end
    end
  end, 80)
end

-- <leader>c* — Claude Code (icons attached via which-key.add below)
vim.keymap.set({ "n", "t" }, "<leader>cc", claude_toggle, { desc = "Toggle Claude Code" })
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
