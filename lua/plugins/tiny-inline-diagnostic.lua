-- Render diagnostic virtual text only on the cursor line (avoids the wall of
-- inline messages across the file). Built-in `virtual_text` stays ON in lsp.lua
-- but only emits an end-of-line `●` (no text), so the two don't fight.
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
