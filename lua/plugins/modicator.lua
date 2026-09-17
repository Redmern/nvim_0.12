-- Colors CursorLineNr per mode (normal/insert/visual/...).
-- Requires number + cursorline + termguicolors — all set in config/options.lua.
--
-- Mode groups are defined explicitly instead of letting modicator derive them
-- from lualine_a_* bgs: make_transparent() (config/autocmds.lua) strips those
-- bgs, which would leave the derived groups colorless. Palette mirrors
-- plugins/lualine.lua so statusline and line number agree per mode.

local function palette()
    local fallback = {
        blue = "#89b4fa",
        green = "#a6e3a1",
        mauve = "#cba6f7",
        red = "#f38ba8",
        peach = "#fab387",
        teal = "#94e2d5",
    }
    local ok, pal = pcall(function()
        return require("catppuccin.palettes").get_palette()
    end)
    if not ok or type(pal) ~= "table" then
        return fallback
    end
    for k, v in pairs(fallback) do
        if not pal[k] then
            pal[k] = v
        end
    end
    return pal
end

local function set_mode_highlights()
    local p = palette()
    local modes = {
        NormalMode = p.blue,
        InsertMode = p.green,
        VisualMode = p.mauve,
        SelectMode = p.mauve,
        ReplaceMode = p.red,
        CommandMode = p.peach,
        TerminalMode = p.teal,
        TerminalNormalMode = p.blue,
    }
    for group, fg in pairs(modes) do
        vim.api.nvim_set_hl(0, group, { fg = fg, bold = true })
    end
end

set_mode_highlights()
-- Re-define after a colorscheme load (theme switch wipes custom groups).
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ModicatorModeHl", { clear = true }),
    callback = set_mode_highlights,
})

require("modicator").setup({
    show_warnings = true, -- warn if number/cursorline/termguicolors go missing
    highlights = { defaults = { bold = true } },
})
