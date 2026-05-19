-- Vertical indent guides. Subtle by default; the scope guide is highlighted
-- so the current scope stands out.
require("ibl").setup({
    indent = { char = "│", tab_char = "│" },
    scope  = { enabled = true, show_start = false, show_end = false },
    exclude = {
        filetypes = {
            "help", "alpha", "dashboard", "neo-tree", "Trouble", "trouble",
            "lazy", "mason", "notify", "toggleterm", "lazyterm", "oil",
            "snacks_dashboard", "dapui_scopes", "dapui_watches",
            "dapui_stacks", "dapui_breakpoints", "dap-repl",
        },
    },
})
