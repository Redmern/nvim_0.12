-- Traditional sidebar file tree. Complements oil.nvim (buffer-as-dir on <leader>e);
-- this one is the classic VS Code-style tree on <leader>E.
require("neo-tree").setup({
  filesystem = {
    follow_current_file = { enabled = true },
    use_libuv_file_watcher = true,
    filtered_items = {
      visible = true,
      hide_dotfiles = false,
      hide_gitignored = false,
    },
  },
  window = {
    width = 45,
    mappings = {
      ["<space>"] = "none", -- free leader inside the tree
      ["l"] = "open",       -- open file / expand folder
      ["h"] = "close_node", -- collapse folder
    },
  },
  default_component_configs = {
    indent = { with_markers = true },
    git_status = { symbols = { unstaged = "", staged = "" } },
  },
})

vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle reveal<cr>", { desc = "Toggle tree" })

-- Pin neo-tree's split so closing the central buffer doesn't make it expand.
-- Use BufWinEnter + WinEnter (same as Claude) — FileType alone misses cases
-- where the buffer is shown in a window asynchronously.
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter", "WinEnter" }, {
  callback = function()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      vim.wo[win].winfixwidth = true
    end
  end,
})
