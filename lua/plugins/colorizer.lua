-- Render `#11111b`, `rgb(...)`, `hsl(...)` etc. with their actual colour.
--
-- The fork takes one table instead of norcalli's two positional arguments.
-- `user_default_options` is the flat legacy option set, which the fork
-- documents as fully supported and translates internally — so these are the
-- same settings as before, not a behaviour change. That set is frozen upstream;
-- newer features (hsluv, css_var, debounce_ms, ...) need the structured
-- `options = { parsers = ..., display = ... }` format instead.
require("colorizer").setup({
    filetypes = {
        "css", "scss", "html", "javascript", "typescript", "tsx", "lua",
        "vim", "cs", "json", "yaml", "markdown",
    },
    user_default_options = {
        RGB      = true,
        RRGGBB   = true,
        RRGGBBAA = true,
        names    = false, -- don't match named colours like "red"; too noisy
        mode     = "background",
    },
})
