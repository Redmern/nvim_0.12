-- C# language server (Roslyn — the same one VS uses).
-- Auto-attaches on .cs files. The roslyn binary is installed via
-- mason-tool-installer (see lua/plugins/dap.lua), from the crashdummyy
-- mason registry registered in lua/plugins/lsp.lua.
--
-- Razor extension is disabled: the current Roslyn binary doesn't recognise
-- the --razorSourceGenerator / --razorDesignTimePath args that newer
-- roslyn.nvim passes by default, which crashes the server on startup.
-- Treesitter still highlights .razor files; you just don't get LSP on them.
require("roslyn").setup({
  extensions = {
    razor = { enabled = false },
  },
})
