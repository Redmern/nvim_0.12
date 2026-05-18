-- blink.cmp pairs well with native 0.12 LSP completion
require("blink.cmp").setup({
    keymap = { preset = "default" },
    sources = { default = { "lsp", "path", "buffer" } },
    completion = { documentation = { auto_show = true } },
    fuzzy = { implementation = "lua" }
})
