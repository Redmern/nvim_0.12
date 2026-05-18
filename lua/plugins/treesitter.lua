require("nvim-treesitter.configs").setup({
    ensure_installed = { "lua", "c_sharp", "vim", "vimdoc", "markdown", "bash", "json", "yaml" },
    auto_install = true,
    highlight = { enable = true },
    indent = { enable = true },
})
