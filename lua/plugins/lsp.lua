-- Diagnostic symbols in the sign column (instead of E/W/I/H letters)
vim.diagnostic.config({
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN]  = "",
            [vim.diagnostic.severity.INFO]  = "",
            [vim.diagnostic.severity.HINT]  = "",
        },
    },
    virtual_text = { prefix = "●" }, -- inline diagnostic bullet style
    severity_sort = true,            -- errors above warnings above info
})

-- Mason — register the crashdummyy registry, which hosts the `roslyn` package
-- (the modern C# language server, configured via roslyn.nvim — see plugins/roslyn.lua).
require("mason").setup({
    registries = {
        "github:mason-org/mason-registry",
        "github:crashdummyy/mason-registry",
    },
})

-- mason-lspconfig handles standard LSPs that ship in the main registry.
-- C# does NOT go here — roslyn.nvim manages the Roslyn server itself.
require("mason-lspconfig").setup({
    ensure_installed = { "lua_ls" },
    automatic_installation = true,
})

-- LSP keymaps on attach (apply to every server, including Roslyn for .cs files)
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local map = function(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = args.buf, desc = desc })
        end
        map("gd", vim.lsp.buf.definition, "Go to definition")
        map("gr", vim.lsp.buf.references, "References")
        map("K", vim.lsp.buf.hover, "Hover")
        map("<leader>lr", vim.lsp.buf.rename, "Rename")
        map("<leader>la", vim.lsp.buf.code_action, "Code action")
        map("<leader>ld", vim.diagnostic.open_float, "Line diagnostics")
    end,
})
