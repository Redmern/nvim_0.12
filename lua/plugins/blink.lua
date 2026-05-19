-- blink.cmp — LSP-driven intellisense. Sources:
--  lsp      — Roslyn / lua_ls / etc. completions, signatures, hover docs
--  lazydev  — Neovim Lua API types (vim.*, plugin source completion)
--  path     — filesystem paths in strings/comments
--  buffer   — words from open buffers (low-priority fallback)
require("blink.cmp").setup({
    keymap = { preset = "super-tab" }, -- <Tab> accepts; jumps snippet placeholders
    snippets = { preset = "luasnip" }, -- friendly-snippets via LuaSnip
    sources = {
        default = { "lsp", "lazydev", "snippets", "path", "buffer" },
        providers = {
            lazydev = {
                name = "LazyDev",
                module = "lazydev.integrations.blink",
                score_offset = 100, -- prefer lazydev's vim.* over generic lsp matches
            },
        },
    },
    completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 150 },
        ghost_text = { enabled = false },                  -- Supermaven owns the ghost-text layer
        menu = { border = "rounded" },
    },
    signature = { enabled = true, window = { border = "rounded" } }, -- live function signature
    cmdline = {
        enabled = true,
        completion = { menu = { auto_show = true } },
    },
    fuzzy = { implementation = "lua" },
})

-- (LSP capabilities are advertised from lua/plugins/lsp.lua, before any
--  vim.lsp.enable() call — that's the only place that gets the timing right.)
