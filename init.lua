-- ============================================================================
-- Neovim 0.12 Configuration
-- Built from scratch using the new built-in plugin manager (vim.pack)
-- ============================================================================

-- Leader keys (set BEFORE plugins load so mappings work correctly)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("plugins")
require("config.autocmds")
require("config.keymaps")
