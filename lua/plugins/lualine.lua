-- Powerline cap glyphs as byte escapes (U+E0B5/E0B7). Kept as escapes on
-- purpose: literal private-use-area chars get mangled by some tooling.
local THIN_L, THIN_R = "\238\130\183", "\238\130\181" -- outline caps

-- Foreground-only "modern" statusline: colored bold mode text + glyph accents,
-- zero explicit backgrounds. Ghostty's opacity bug (ghostty#7957) mangles
-- explicit-bg cells outside tmux, so a bg-free theme is the only design that
-- renders identically inside and outside tmux. Don't reintroduce section
-- backgrounds / pills while that bug is unfixed.

-- Per-mode accent colors. Pulled from the catppuccin palette when it's the
-- active colorscheme family, with hardcoded mocha values as fallback so other
-- themes still get a sane look.
local function palette()
    local fallback = {
        blue = "#89b4fa", green = "#a6e3a1", mauve = "#cba6f7", red = "#f38ba8",
        peach = "#fab387", yellow = "#f9e2af", text = "#cdd6f4", overlay1 = "#7f849c",
        crust = "#11111b",
    }
    local ok, pal = pcall(function()
        return require("catppuccin.palettes").get_palette()
    end)
    if not ok or type(pal) ~= "table" then return fallback end
    for k, v in pairs(fallback) do
        if not pal[k] then pal[k] = v end
    end
    return pal
end

local function fg_theme()
    local p = palette()
    local function mode(accent)
        return {
            a = { fg = accent, bg = "NONE", gui = "bold" },
            b = { fg = p.overlay1, bg = "NONE" },
            c = { fg = p.text, bg = "NONE" },
        }
    end
    return {
        normal   = mode(p.blue),
        insert   = mode(p.green),
        visual   = mode(p.mauve),
        replace  = mode(p.red),
        command  = mode(p.peach),
        terminal = mode(p.green),
        inactive = {
            a = { fg = p.overlay1, bg = "NONE" },
            b = { fg = p.overlay1, bg = "NONE" },
            c = { fg = p.overlay1, bg = "NONE" },
        },
    }
end

local function apply()
    require("lualine").setup({
        options = {
            theme = fg_theme(),
            globalstatus = true,
            -- bg-free design: glyph separators read as accents, not pill edges
            section_separators = "",
            component_separators = { left = "│", right = "│" },
            disabled_filetypes = { statusline = { "dashboard", "alpha" } },
        },
        sections = {
            -- "outlined pill": thin rounded cap glyphs ( U+E0B7 /  U+E0B5)
            -- drawn as plain fg text — pill silhouette with zero bg cells.
            lualine_a = { { "mode", fmt = function(s) return THIN_L .. " " .. s .. " " .. THIN_R end, padding = 0 } },
            lualine_b = { { "branch", icon = "" } },
            lualine_c = {
                {
                    "diagnostics",
                    symbols = { error = " ", warn = " ", info = " ", hint = " " },
                },
                { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
                { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" } },
            },
            lualine_x = {
                {
                    "diff",
                    symbols = { added = " ", modified = " ", removed = " " },
                },
            },
            lualine_y = {
                { "progress", separator = " ", padding = { left = 1, right = 0 } },
                { "location", padding = { left = 0, right = 1 } },
            },
            -- no time here: the tmux status bar already shows it
            lualine_z = {},
        },
        extensions = { "neo-tree", "lazy", "toggleterm", "oil" },
    })
end

apply()

-- Re-apply whenever the colorscheme changes. sync_os_theme in config/autocmds
-- applies the colorscheme AFTER plugins load, so without this hook lualine
-- stays stuck on the palette it computed before any colorscheme existed.
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply })
vim.api.nvim_create_autocmd("OptionSet", { pattern = "background", callback = apply })
