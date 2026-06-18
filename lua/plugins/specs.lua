-- Plugin specs. Single source of truth for what gets cloned by vim.pack.
-- Each plugin's setup lives in lua/plugins/<name>.lua; this file just lists
-- repositories.
return {
    -- Themes (active one is picked by Omarchy sync in lua/config/autocmds.lua)
    { src = "https://github.com/catppuccin/nvim",                          name = "catppuccin" },
    { src = "https://github.com/folke/tokyonight.nvim" },
    { src = "https://github.com/rebelot/kanagawa.nvim" },
    { src = "https://github.com/rose-pine/neovim",                         name = "rose-pine" },
    { src = "https://github.com/ellisonleao/gruvbox.nvim" },
    { src = "https://github.com/sainnhe/everforest" },
    { src = "https://github.com/shaunsingh/nord.nvim" },
    { src = "https://github.com/Mofiqul/dracula.nvim" },
    { src = "https://github.com/gthelding/monokai-pro.nvim",               name = "monokai-pro" },

    -- File explorer (buffer-as-directory) + traditional sidebar tree
    { src = "https://github.com/stevearc/oil.nvim" },
    { src = "https://github.com/nvim-neo-tree/neo-tree.nvim" },

    { src = "https://github.com/folke/which-key.nvim" },

    -- Syntax (main branch — master is archived, see treesitter.lua for why)
    { src = "https://github.com/nvim-treesitter/nvim-treesitter",          version = "main" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },

    -- LSP + tooling
    { src = "https://github.com/neovim/nvim-lspconfig" },
    { src = "https://github.com/mason-org/mason.nvim" },
    { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
    { src = "https://github.com/folke/lazydev.nvim" },

    -- Debugger
    { src = "https://github.com/mfussenegger/nvim-dap" },
    { src = "https://github.com/rcarriga/nvim-dap-ui" },
    { src = "https://github.com/nvim-neotest/nvim-nio" },
    -- (dap-cs intentionally NOT installed — it overwrites dap.configurations.cs)
    { src = "https://github.com/theHamsta/nvim-dap-virtual-text" },
    { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },

    -- Test runner (xUnit / nUnit via dotnet)
    { src = "https://github.com/nvim-neotest/neotest" },
    { src = "https://github.com/Issafalcon/neotest-dotnet" },

    -- Completion (LSP-backed) + Supermaven AI ghost text
    { src = "https://github.com/saghen/blink.cmp" },
    { src = "https://github.com/saghen/blink.lib" },
    { src = "https://github.com/supermaven-inc/supermaven-nvim" },

    -- Snippets (LuaSnip engine + friendly-snippets library; blink uses them)
    { src = "https://github.com/L3MON4D3/LuaSnip" },
    { src = "https://github.com/rafamadriz/friendly-snippets" },

    -- Pickers — fff for files + grep; plenary kept as transitive dep of
    -- neo-tree / neotest / lazygit / nvim-notify / harpoon
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/dmtrKovalenko/fff.nvim" },

    -- Harpoon (v2) — pin a handful of files, jump with <leader>1..4
    { src = "https://github.com/ThePrimeagen/harpoon",                     version = "harpoon2" },

    -- UI: tabs, status, icons, indent guides, hex-colour preview, markdown render
    { src = "https://github.com/akinsho/bufferline.nvim" },
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/lukas-reineke/indent-blankline.nvim" },
    { src = "https://github.com/norcalli/nvim-colorizer.lua" },
    { src = "https://github.com/MeanderingProgrammer/render-markdown.nvim" },
    { src = "https://github.com/s1n7ax/nvim-window-picker" },

    -- Git
    { src = "https://github.com/kdheepak/lazygit.nvim" },
    { src = "https://github.com/lewis6991/gitsigns.nvim" },
    -- Project-wide find &amp; replace
    { src = "https://github.com/MagicDuck/grug-far.nvim" },

    -- Diagnostics / quickfix browser + sessions
    { src = "https://github.com/folke/trouble.nvim" },
    { src = "https://github.com/folke/persistence.nvim" },

    -- Format
    { src = "https://github.com/stevearc/conform.nvim" },

    -- Motion / navigation
    { src = "https://github.com/folke/flash.nvim" },
    { src = "https://github.com/christoomey/vim-tmux-navigator" },
    { src = "https://github.com/akinsho/toggleterm.nvim" },

    -- mini.* umbrella — single repo, multiple modules (ai, pairs, comment, surround)
    { src = "https://github.com/echasnovski/mini.nvim" },

    -- Inline diagnostics on cursor line
    { src = "https://github.com/rachartier/tiny-inline-diagnostic.nvim" },

    -- Floating cmdline + prettier notifications
    { src = "https://github.com/folke/noice.nvim" },
    { src = "https://github.com/MunifTanjim/nui.nvim" },
    { src = "https://github.com/rcarriga/nvim-notify" },

    -- AI side panels
    { src = "https://github.com/coder/claudecode.nvim" },
    -- omp has no nvim plugin yet → driven via lua/plugins/omp.lua (terminal split)
}
