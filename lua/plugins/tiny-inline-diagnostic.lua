-- Render diagnostic virtual text only on the cursor line (avoids the wall of
-- inline messages across the file). Built-in `virtual_text` is turned off in
-- lsp.lua so the two don't fight.
require("tiny-inline-diagnostic").setup({
    signs = {
        left = "",
        right = "",
        diag = "●",
        arrow = "    ",
        up_arrow = "    ",
        vertical = " │",
        vertical_end = " └",
    },
    blend = { factor = 0.22 },
})
