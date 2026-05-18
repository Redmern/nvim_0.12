-- Plugins (Neovim 0.12 built-in plugin manager: vim.pack)
vim.pack.add({
    -- Themes (active one is picked by Omarchy sync in lua/config/autocmds.lua)
    { src = "https://github.com/catppuccin/nvim",                 name = "catppuccin" },
    { src = "https://github.com/folke/tokyonight.nvim" },
    { src = "https://github.com/rebelot/kanagawa.nvim" },
    { src = "https://github.com/rose-pine/neovim",                name = "rose-pine" },
    { src = "https://github.com/ellisonleao/gruvbox.nvim" },
    { src = "https://github.com/sainnhe/everforest" },
    { src = "https://github.com/shaunsingh/nord.nvim" },
    { src = "https://github.com/Mofiqul/dracula.nvim" },

    -- File explorer
    { src = "https://github.com/stevearc/oil.nvim" },

    -- Keymap discovery
    { src = "https://github.com/folke/which-key.nvim" },

    -- Syntax
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "master" },

    -- LSP + tooling
    { src = "https://github.com/neovim/nvim-lspconfig" },
    { src = "https://github.com/mason-org/mason.nvim" },
    { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
    { src = "https://github.com/folke/lazydev.nvim" }, -- Neovim Lua API intellisense for lua_ls
    { src = "https://github.com/seblyng/roslyn.nvim" }, -- C# LSP (modern replacement for omnisharp)

    -- Debugger
    { src = "https://github.com/mfussenegger/nvim-dap" },
    { src = "https://github.com/rcarriga/nvim-dap-ui" },
    { src = "https://github.com/nvim-neotest/nvim-nio" },               -- dap-ui dep
    { src = "https://github.com/nicholasmata/nvim-dap-cs" },            -- C# adapter wrapper around netcoredbg
    { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" }, -- declarative install of non-LSP Mason tools

    -- Completion (lightweight, no snippet engine bloat)
    { src = "https://github.com/saghen/blink.cmp" },
    { src = "https://github.com/saghen/blink.lib" }, -- required by blink.cmp v2

    -- Telescope (fuzzy finder)
    { src = "https://github.com/nvim-telescope/telescope.nvim" },
    { src = "https://github.com/nvim-lua/plenary.nvim" }, -- telescope dep

    -- Bufferline (tabs at the top)
    { src = "https://github.com/akinsho/bufferline.nvim" },

    -- Statusline
    { src = "https://github.com/nvim-lualine/lualine.nvim" },

    -- Git
    { src = "https://github.com/kdheepak/lazygit.nvim" },

    -- Format / lint
    { src = "https://github.com/stevearc/conform.nvim" },

    -- Icons (used by bufferline, oil, telescope, lualine)
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },

    -- Motion (s/S to jump anywhere visible)
    { src = "https://github.com/folke/flash.nvim" },

    -- Ctrl+h/j/k/l navigates nvim splits + (when present) tmux panes seamlessly
    { src = "https://github.com/christoomey/vim-tmux-navigator" },

    -- Ctrl+/ toggles an embedded terminal
    { src = "https://github.com/akinsho/toggleterm.nvim" },

    -- Extended a/i text-objects (any-bracket, any-quote, next/last, custom "g" = entire buffer)
    { src = "https://github.com/echasnovski/mini.ai" },

    -- Floating cmdline + nicer messages/notifications
    { src = "https://github.com/folke/noice.nvim" },
    { src = "https://github.com/MunifTanjim/nui.nvim" }, -- required by noice
    { src = "https://github.com/rcarriga/nvim-notify" }, -- optional, prettier notifications

    -- AI harnesses
    { src = "https://github.com/coder/claudecode.nvim" },
    { src = "https://github.com/nickjvandyke/opencode.nvim" },
})

require("plugins.catppuccin")
require("plugins.oil")
require("plugins.which-key")
require("plugins.treesitter")
require("plugins.lsp")
require("plugins.lazydev")
require("plugins.roslyn")
require("plugins.dap")
require("plugins.blink")
require("plugins.telescope")
require("plugins.bufferline")
require("plugins.lualine")
require("plugins.lazygit")
require("plugins.conform")
require("plugins.flash")
require("plugins.noice")
require("plugins.mini-ai")
require("plugins.claudecode")
require("plugins.opencode")
require("plugins.tmux-navigator")
require("plugins.toggleterm")
