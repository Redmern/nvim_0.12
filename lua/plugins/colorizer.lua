-- Render `#11111b`, `rgb(...)`, `hsl(...)` etc. with their actual colour.
require("colorizer").setup({
    "css", "scss", "html", "javascript", "typescript", "tsx", "lua",
    "vim", "cs", "json", "yaml", "markdown",
}, {
    RGB      = true,
    RRGGBB   = true,
    RRGGBBAA = true,
    names    = false, -- don't match named colours like "red"; too noisy
    mode     = "background",
})
