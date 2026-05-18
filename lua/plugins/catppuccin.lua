require("catppuccin").setup({
    flavour = "auto", -- auto picks latte (light) or mocha (dark)
    background = { light = "latte", dark = "mocha" },
    integrations = {
        treesitter = true,
        telescope = { enabled = true },
        mason = true,
        native_lsp = { enabled = true },
        which_key = true,
    },
})
-- Note: colorscheme selection lives in lua/config/autocmds.lua (Omarchy theme sync).
