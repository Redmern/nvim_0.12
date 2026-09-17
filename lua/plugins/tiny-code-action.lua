-- Code-action picker with a diff preview of what each action would change.
-- Replaces the bare vim.ui.select list behind <leader>la (mapped in lsp.lua's
-- LspAttach, with a fallback to vim.lsp.buf.code_action if this fails to load).
--
-- picker = "buffer": the plugin's own floating window. No telescope/fzf/snacks
-- here (fff is the file picker and has no generic select API), and the buffer
-- picker is the only one that shows the preview inline.
-- backend = "vim": built-in diff, no delta/difftastic binary needed.
require("tiny-code-action").setup({
    backend = "vim",
    picker = {
        "buffer",
        opts = {
            hotkeys = true, -- one-key apply; letters derived from the action text
            hotkeys_mode = "text_diff_based",
            auto_preview = true, -- show the diff for the highlighted action immediately
            auto_accept = false,
            position = "cursor",
            winborder = "rounded",
            keymaps = {
                preview = "K",
                close = { "q", "<Esc>" },
                select = "<CR>",
                preview_close = { "q", "<Esc>" },
            },
        },
    },
    resolve_timeout = 100,
    notify = { enabled = true, on_empty = true },
})
