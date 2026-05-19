-- nvim-web-devicons setup. Loaded before bufferline/neo-tree/lualine so
-- they all get colored file icons instead of monochrome fallbacks.
require("nvim-web-devicons").setup({
    color_icons = true,
    default = true,
    strict = true,
})
