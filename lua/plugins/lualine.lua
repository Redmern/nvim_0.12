-- Filled "bubbles" statusline: each end is a rounded pill (solid bg + round
-- cap glyphs U+E0B6 / U+E0B4), the middle is a solid bar.
--
-- This used to branch on $TMUX because Ghostty's opacity-stacking bug
-- (#7957/#8642) made explicit-bg cells render wrong outside tmux under
-- background-opacity < 1. The terminal now runs at background-opacity = 1.0
-- (see ~/.config/ghostty/config), which sidesteps the bug, so pills render
-- identically in and out of tmux -- no branch needed.
--
-- Toggling nvim transparency on (<leader>ut) still re-strips ^lualine_ bgs via
-- config/autocmds.lua make_transparent, flattening these to a fg-only bar.
-- Caps kept as byte escapes: literal PUA chars get mangled by tooling.
local CAP_L, CAP_R = "\238\130\182", "\238\130\180" -- U+E0B6 (left) / U+E0B4 (right) filled round caps

-- Per-mode accent + surface colors. Pulled from the catppuccin palette when
-- it's available, with hardcoded mocha values as fallback so other themes still
-- get a sane look.
local function palette()
    local fallback = {
        blue = "#89b4fa", green = "#a6e3a1", mauve = "#cba6f7", red = "#f38ba8",
        peach = "#fab387", yellow = "#f9e2af", text = "#cdd6f4", overlay1 = "#7f849c",
        crust = "#11111b", mantle = "#181825", surface0 = "#313244", surface1 = "#45475a",
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

local function pill_theme()
    local p = palette()
    -- a = filled accent pill (mode), b = raised surface, c = solid bar body
    local function mode(accent)
        return {
            a = { fg = p.crust, bg = accent, gui = "bold" },
            b = { fg = p.text, bg = p.surface0 },
            c = { fg = p.text, bg = p.mantle },
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
            a = { fg = p.overlay1, bg = p.mantle },
            b = { fg = p.overlay1, bg = p.mantle },
            c = { fg = p.overlay1, bg = p.mantle },
        },
    }
end

local function apply()
    require("lualine").setup({
        options = {
            theme = pill_theme(),
            globalstatus = true,
            component_separators = "",
            section_separators = { left = CAP_R, right = CAP_L },
            disabled_filetypes = { statusline = { "dashboard", "alpha" } },
        },
        sections = {
            -- left pill: rounded cap on the outside edge of the mode block
            lualine_a = { { "mode", separator = { left = CAP_L }, padding = { left = 1, right = 1 } } },
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
            lualine_y = { { "progress" } },
            -- right pill: rounded cap on the outside edge of the location block
            lualine_z = { { "location", separator = { right = CAP_R }, padding = { left = 1, right = 1 } } },
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

-- Startup heal: lualine.setup() above runs before config/autocmds.lua applies
-- the Omarchy colorscheme, and the startup colorscheme churn (plus lualine's
-- own internal ColorScheme refresh) can leave the pill highlights — lualine_a
-- bg etc. — empty on a fresh launch, with no further ColorScheme event to fix
-- them. A post-startup re-apply, deferred until the event loop is idle, makes a
-- cold-started nvim render the filled pills without needing a manual toggle.
vim.api.nvim_create_autocmd("VimEnter", { callback = function() vim.schedule(apply) end })
