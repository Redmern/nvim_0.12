require("noice").setup({
    presets = {
        bottom_search = false,    -- float "/" search too (set true to keep at bottom)
        command_palette = false,  -- true = combined cmdline + popupmenu at top
        long_message_to_split = true, -- long :messages open in a split instead of a tiny float
        inc_rename = false,
        lsp_doc_border = true,    -- bordered LSP hover/signature
    },
})
