-- Ctrl+h/j/k/l moves between nvim splits.
-- If nvim is running inside tmux, the same keys cross into adjacent tmux panes
-- (provided the matching snippet is in your ~/.tmux.conf — see the plugin README).
vim.keymap.set({ "n", "t" }, "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  { desc = "Window/pane left"  })
vim.keymap.set({ "n", "t" }, "<C-j>", "<cmd>TmuxNavigateDown<cr>",  { desc = "Window/pane down"  })
vim.keymap.set({ "n", "t" }, "<C-k>", "<cmd>TmuxNavigateUp<cr>",    { desc = "Window/pane up"    })
vim.keymap.set({ "n", "t" }, "<C-l>", "<cmd>TmuxNavigateRight<cr>", { desc = "Window/pane right" })
