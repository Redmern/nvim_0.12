-- nvim-notify wants either a NotifyBackground hl or an explicit colour;
-- without it we get the "no background highlight" warning every notify.
-- max_height caps every notification popup (errors included) at 5 lines;
-- the full text stays in :Noice history and the on-disk error log.
require("notify").setup({ background_colour = "#000000", max_height = 5 })

local error_log = require("util.error-log")

require("noice").setup({
    routes = {
        -- Side-effect only: cond logs errors to disk and returns false, so
        -- the message falls through to the routes below. `:ErrorLog` opens it.
        { filter = { cond = error_log.noice_cond } },
        -- Keep errors in the (height-capped) notify popup, even long ones
        -- that long_message_to_split would otherwise open as a split.
        { filter = { error = true }, view = "notify" },
    },
    presets = {
        bottom_search = false,    -- float "/" search too (set true to keep at bottom)
        command_palette = false,  -- true = combined cmdline + popupmenu at top
        long_message_to_split = true, -- long :messages open in a split instead of a tiny float
        inc_rename = false,
        lsp_doc_border = true,    -- bordered LSP hover/signature
    },
})
