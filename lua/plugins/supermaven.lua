-- Supermaven inline AI ghost-text. First run: `:SupermavenUseFree`
-- (or `:SupermavenUsePro` and follow the auth URL).
require("supermaven-nvim").setup({
    keymaps = {
        accept_suggestion = "<C-y>",  -- avoid clashing with blink.cmp's <Tab>
        accept_word       = "<C-l>",
        clear_suggestion  = "<C-]>",
    },
    ignore_filetypes = {
        ["neo-tree"]      = true,
        oil               = true,
        TelescopePrompt   = true,
        ["dap-repl"]      = true,
        dapui_scopes      = true,
        dapui_breakpoints = true,
        dapui_stacks      = true,
        dapui_watches     = true,
        gitcommit         = true,
    },
    color = { suggestion_color = "#6c7086", cterm = 244 },
})
