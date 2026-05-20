-- Monokai-Pro Ristretto: warm amber theme used by the Omarchy `space-monkey`
-- pack. Setup mirrors ~/.config/omarchy/current/theme/neovim.lua so colours
-- match the rest of the desktop. Colourscheme is applied by the Omarchy sync
-- autocmd in lua/config/autocmds.lua, not here.
require("monokai-pro").setup({
    filter = "ristretto",
    override = function()
        return {
            NonText         = { fg = "#948a8b" },
            MiniIconsGrey   = { fg = "#948a8b" },
            MiniIconsRed    = { fg = "#fd6883" },
            MiniIconsBlue   = { fg = "#85dacc" },
            MiniIconsGreen  = { fg = "#adda78" },
            MiniIconsYellow = { fg = "#f9cc6c" },
            MiniIconsOrange = { fg = "#f38d70" },
            MiniIconsPurple = { fg = "#a8a9eb" },
            MiniIconsAzure  = { fg = "#a8a9eb" },
            MiniIconsCyan   = { fg = "#85dacc" },
        }
    end,
})
