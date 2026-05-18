require("conform").setup({
    formatters_by_ft = {
        cs   = { "csharpier" },
        lua  = { "stylua" },
        json = { "prettier" },
    },
    format_on_save = { timeout_ms = 1000, lsp_fallback = true },
})

vim.keymap.set("n", "<leader>lf", function() require("conform").format() end, { desc = "Format" })
