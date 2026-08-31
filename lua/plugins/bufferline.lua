-- Pill-style tabs matching the tmux status bar: the active buffer sits in a
-- filled rounded pill (darker than the tmux ones — surface0), inactive
-- buffers get a fainter rounded pill (pill_dim, backdrop blended toward
-- surface0 — see build_opts). Rounded caps come from hijacking bufferline's
-- "slope" separator style — it's the only style that draws a separator on
-- BOTH sides of every tab, which is what a pill needs.
local CAP_L, CAP_R = "\238\130\182", "\238\130\180" -- U+E0B6 / U+E0B4 as byte escapes

-- slope's chars are { right, left }; swap the slanted glyphs for round caps.
local constants = require("bufferline.constants")
constants.sep_chars.slope = { CAP_R, CAP_L }

-- Second hijack, same reason as the first. For any slant/slope style bufferline
-- hardcodes the indicator segment to `{ text = " ", highlight = nil }`
-- (ui.lua `add_indicator`), and a nil highlight emits no `%#Group#` — so that
-- cell inherits whatever came before it. That's the left cap, drawn with
-- `separator_selected` (bg = NONE, fg = pill, so the arc's outer corners stay
-- transparent and the cap reads as round). Net effect: a one-cell transparent
-- notch bitten out of the pill between the cap and the tab body, visible only
-- on the active tab. (Inactive tabs are a flat pill_dim chip, so the notch
-- would show there too — the patch loop stamps every element's buffer hl, not
-- just the selected one, which covers both.)
--
-- Not fixable from opts: `indicator.style` is only consulted *after* the slant
-- early-return, and giving `separator_selected` a bg squares off the cap.
-- So stamp the buffer highlight (the pill bg) onto that one cell.
--
-- Nothing here is OS-specific; what it *is* coupled to is bufferline's internals
-- (pinned at 655133c3 in nvim-pack-lock.json). Every step is therefore optional:
-- a missing module, a renamed `ui.element`, or an upstream fix that stops
-- emitting the nil-highlight cell all leave this a silent no-op rather than a
-- broken tabline. The `__pill_indicator_patched` flag keeps `:source %` from
-- stacking a fresh wrapper on every reload.
local ok_ui, ui = pcall(require, "bufferline.ui")
local ok_hl, ui_highlights = pcall(require, "bufferline.highlights")

if ok_ui and ok_hl and type(ui.element) == "function" and not ui.__pill_indicator_patched then
    ui.__pill_indicator_patched = true

    local PADDING = constants.padding
    local render_element = ui.element

    ui.element = function(state, element)
        local el = render_element(state, element)
        if type(el) ~= "table" or type(el.component) ~= "function" then return el end

        local ok, buffer_hl = pcall(function() return ui_highlights.for_element(element).buffer end)
        if not ok or not buffer_hl then return el end

        local render = el.component
        el.component = function(next_item)
            local segments = render(next_item)
            if type(segments) ~= "table" then return segments end
            for _, segment in ipairs(segments) do
                if segment.highlight == nil and segment.text == PADDING then
                    segment.highlight = buffer_hl
                    break
                end
            end
            return segments
        end
        return el
    end
end

-- Follow the active Omarchy theme (same source as lualine — util/omarchy-palette
-- parses the theme's ghostty.conf). Falls back to catppuccin, then a mocha table,
-- so a box without Omarchy still gets sane pill colours. Re-read on every
-- ColorScheme via the setup() call at the bottom of this file.
local FALLBACK = {
    surface0 = "#313244", mantle = "#181825", text = "#cdd6f4",
    overlay1 = "#7f849c", overlay0 = "#6c7086", peach = "#fab387",
}

local function palette()
    local ok, p = pcall(function() return require("util.omarchy-palette").get() end)
    if ok and type(p) == "table" then
        for k, v in pairs(FALLBACK) do
            if not p[k] then p[k] = v end
        end
        p.__omarchy = true -- mantle/bg came from the theme's ghostty.conf (= terminal bg)
        return p
    end
    local ok2, cp = pcall(function() return require("catppuccin.palettes").get_palette() end)
    if ok2 and type(cp) == "table" then
        for k, v in pairs(FALLBACK) do
            if not cp[k] then cp[k] = v end
        end
        return cp
    end
    return FALLBACK
end

-- Mix two "#rrggbb" by t (0 = a, 1 = b).
local function blend(a, b, t)
    local function rgb(h) return tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16) end
    local ar, ag, ab = rgb(a)
    local br, bg, bb = rgb(b)
    return string.format("#%02x%02x%02x",
        math.floor(ar + (br - ar) * t + 0.5),
        math.floor(ag + (bg - ag) * t + 0.5),
        math.floor(ab + (bb - ab) * t + 0.5))
end

local function build_opts()
    local p = palette()
    local pill = p.surface0 or "#313244" -- active-tab pill
    -- Inactive tab end-caps are drawn as a solid glyph in this fg; to read as
    -- "no pill" it must equal the editor backdrop exactly. omarchy-palette's
    -- mantle IS the terminal bg (parsed from the theme's ghostty.conf), so trust
    -- it when present. Only when that whole path failed (catppuccin fallback,
    -- whose mantle #181825 is darker than most theme bgs and shows as dark
    -- wedges) do we fall back to the live Normal bg / hardcoded shade.
    local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
    local ghost = p.__omarchy and p.mantle
        or (normal_bg and string.format("#%06x", normal_bg))
        or p.mantle or "#181825"
    local text = p.text or "#cdd6f4"
    local dim = p.overlay1 or p.overlay0 or "#6c7086"
    local peach = p.peach or "#fab387"
    -- Inactive tabs get their own rounded pill too, a subtle one: backdrop
    -- blended ~40% toward the active pill so it reads as a chip, not a slab.
    local pill_dim = blend(ghost, pill, 0.4)
    local selected = { bg = pill, fg = text }
    return {
        options = {
            diagnostics = "nvim_lsp",
            diagnostics_update_in_insert = false, -- silences the bufferline 4.6.3 deprecation warning
            always_show_bufferline = false,
            show_buffer_close_icons = true,
            show_close_icon = false,
            color_icons = true,
            separator_style = "slope", -- patched above to round caps
            offsets = {
                { filetype = "neo-tree", text = "Neo-tree", highlight = "Directory", text_align = "left" },
            },
            -- Hide terminal buffers (Claude Code, omp, :terminal) from the bufferline
            custom_filter = function(buf_number)
                return vim.bo[buf_number].buftype ~= "terminal"
            end,
        },
        -- Transparent bar; this file owns every BufferLine bg (autocmds no
        -- longer strips ^BufferLine, so the selected pill bg survives).
        -- Inactive caps: fg AND bg both = "ghost" (the real backdrop shade). The
        -- cap is a solid arc glyph; with bg = NONE its antialiased edge blends
        -- toward transparent and leaves a faint outline on every inactive tab
        -- ("darker sides"). Filling the cap cell with the backdrop colour makes
        -- the glyph vanish. (Selected caps keep bg = NONE so the pill's outer
        -- corners stay round — see the indicator-patch note at the top.)
        --
        -- Inactive tabs are now their own `pill_dim` chip. Their caps
        -- (separator / separator_visible) draw the arc glyph in `pill_dim` with
        -- bg = NONE, so the outer corners stay transparent and read as round —
        -- same trick as separator_selected. The indicator patch at the top
        -- stamps the buffer highlight (pill_dim) onto the notch cell for these
        -- too, so the chip is gap-free.
        highlights = {
            fill = { bg = "NONE" },
            background = { bg = pill_dim, fg = dim },
            buffer_visible = { bg = pill_dim, fg = dim },
            buffer_selected = { bg = pill, fg = text, bold = true, italic = false },
            separator = { bg = "NONE", fg = pill_dim },
            separator_visible = { bg = "NONE", fg = pill_dim },
            separator_selected = { bg = "NONE", fg = pill },
            close_button = { bg = pill_dim, fg = dim },
            close_button_visible = { bg = pill_dim, fg = dim },
            close_button_selected = selected,
            modified = { bg = pill_dim, fg = peach },
            modified_visible = { bg = pill_dim, fg = peach },
            modified_selected = { bg = pill, fg = peach },
            duplicate = { bg = pill_dim, fg = dim, italic = true },
            duplicate_visible = { bg = pill_dim, fg = dim, italic = true },
            duplicate_selected = { bg = pill, fg = dim, italic = true },
            indicator_visible = { bg = pill_dim },
            indicator_selected = selected,
            pick = { bg = pill_dim, bold = true },
            pick_visible = { bg = pill_dim, bold = true },
            pick_selected = { bg = pill, bold = true },
            diagnostic = { bg = pill_dim },
            diagnostic_visible = { bg = pill_dim },
            diagnostic_selected = { bg = pill },
            error = { bg = pill_dim, fg = dim },
            error_visible = { bg = pill_dim, fg = dim },
            error_selected = selected,
            error_diagnostic = { bg = pill_dim, fg = dim },
            error_diagnostic_visible = { bg = pill_dim, fg = dim },
            error_diagnostic_selected = selected,
            warning = { bg = pill_dim, fg = dim },
            warning_visible = { bg = pill_dim, fg = dim },
            warning_selected = selected,
            warning_diagnostic = { bg = pill_dim, fg = dim },
            warning_diagnostic_visible = { bg = pill_dim, fg = dim },
            warning_diagnostic_selected = selected,
            info = { bg = pill_dim, fg = dim },
            info_visible = { bg = pill_dim, fg = dim },
            info_selected = selected,
            info_diagnostic = { bg = pill_dim, fg = dim },
            info_diagnostic_visible = { bg = pill_dim, fg = dim },
            info_diagnostic_selected = selected,
            hint = { bg = pill_dim, fg = dim },
            hint_visible = { bg = pill_dim, fg = dim },
            hint_selected = selected,
            hint_diagnostic = { bg = pill_dim, fg = dim },
            hint_diagnostic_visible = { bg = pill_dim, fg = dim },
            hint_diagnostic_selected = selected,
        },
    }
end

require("bufferline").setup(build_opts())

-- Omarchy theme sync (config/autocmds.lua) re-runs :colorscheme on FocusGained.
-- Bufferline caches its derived hl groups at setup() time → they go stale and
-- everything turns grey. Re-init on every ColorScheme to refresh (rebuilds the
-- palette-derived pill colors too).
vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function() require("bufferline").setup(build_opts()) end,
})

-- Shift-L / Shift-H to switch tabs
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })

-- Layout-preserving buffer delete: switch the window to another listed buffer
-- (or a scratch buf if none) before wiping the target. Without this, closing
-- the last code buffer collapses the central window and the side panels
-- (neo-tree, Claude) grow to fill the empty space.
local function close_buffer_keep_layout()
    local bufnr = vim.api.nvim_get_current_buf()

    local alt = vim.fn.bufnr("#")
    if alt < 1 or alt == bufnr or not vim.api.nvim_buf_is_valid(alt)
       or not vim.bo[alt].buflisted then
        alt = -1
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if b ~= bufnr and vim.bo[b].buflisted and vim.bo[b].buftype == "" then
                alt = b; break
            end
        end
    end

    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
        vim.api.nvim_win_call(win, function()
            if alt > 0 then
                vim.api.nvim_win_set_buf(win, alt)
            else
                vim.cmd("enew") -- fresh empty buffer keeps the window alive
            end
        end)
    end
    pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
end

vim.keymap.set("n", "<leader>bd", close_buffer_keep_layout, { desc = "Close tab (keep layout)" })

-- Hook :bd / :bdelete / :BD into the same layout-preserving function. The
-- cabbrev only fires when bd/bdelete is the FIRST token, so things like
-- `:silent! bd` from plugins are unaffected.
vim.api.nvim_create_user_command("BD", close_buffer_keep_layout, { desc = "Close buffer (keep layout)" })
vim.cmd([[
    cnoreabbrev <expr> bd      (getcmdtype() == ':' && getcmdline() ==# 'bd')      ? 'BD' : 'bd'
    cnoreabbrev <expr> bdelete (getcmdtype() == ':' && getcmdline() ==# 'bdelete') ? 'BD' : 'bdelete'
]])
vim.keymap.set("n", "<leader>ba", "<cmd>%bdelete<cr>", { desc = "Close all buffers" })
vim.keymap.set("n", "<leader>be", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
