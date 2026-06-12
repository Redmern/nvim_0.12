-- Pill-style tabs matching the tmux status bar: the active buffer sits in a
-- filled rounded pill (darker than the tmux ones — surface0), inactive
-- buffers are plain dim text. Rounded caps come from hijacking bufferline's
-- "slope" separator style — it's the only style that draws a separator on
-- BOTH sides of every tab, which is what a pill needs.
local CAP_L, CAP_R = "\238\130\182", "\238\130\180" -- U+E0B6 / U+E0B4 as byte escapes

-- slope's chars are { right, left }; swap the slanted glyphs for round caps.
require("bufferline.constants").sep_chars.slope = { CAP_R, CAP_L }

local function palette()
    local ok, p = pcall(function() return require("catppuccin.palettes").get_palette() end)
    return (ok and type(p) == "table") and p or {}
end

local function build_opts()
    local p = palette()
    local pill = p.surface0 or "#313244" -- active-tab pill, darker than the tmux blue
    local ghost = p.mantle or "#181825" -- ~invisible over the dark backdrop
    local text = p.text or "#cdd6f4"
    local dim = p.overlay0 or "#6c7086"
    local peach = p.peach or "#fab387"
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
            -- Hide terminal buffers (Claude Code, opencode, :terminal) from the bufferline
            custom_filter = function(buf_number)
                return vim.bo[buf_number].buftype ~= "terminal"
            end,
        },
        -- Transparent bar; this file owns every BufferLine bg (autocmds no
        -- longer strips ^BufferLine, so the selected pill bg survives).
        -- Inactive caps use the "ghost" shade — close enough to the backdrop
        -- to read as no pill at all.
        highlights = {
            fill = { bg = "NONE" },
            background = { bg = "NONE", fg = dim },
            buffer_visible = { bg = "NONE", fg = dim },
            buffer_selected = { bg = pill, fg = text, bold = true, italic = false },
            separator = { bg = "NONE", fg = ghost },
            separator_visible = { bg = "NONE", fg = ghost },
            separator_selected = { bg = "NONE", fg = pill },
            close_button = { bg = "NONE", fg = dim },
            close_button_visible = { bg = "NONE", fg = dim },
            close_button_selected = selected,
            modified = { bg = "NONE", fg = peach },
            modified_visible = { bg = "NONE", fg = peach },
            modified_selected = { bg = pill, fg = peach },
            duplicate = { bg = "NONE", fg = dim, italic = true },
            duplicate_visible = { bg = "NONE", fg = dim, italic = true },
            duplicate_selected = { bg = pill, fg = dim, italic = true },
            indicator_visible = { bg = "NONE" },
            indicator_selected = selected,
            pick = { bg = "NONE", bold = true },
            pick_visible = { bg = "NONE", bold = true },
            pick_selected = { bg = pill, bold = true },
            diagnostic = { bg = "NONE" },
            diagnostic_visible = { bg = "NONE" },
            diagnostic_selected = { bg = pill },
            error = { bg = "NONE", fg = dim },
            error_visible = { bg = "NONE", fg = dim },
            error_selected = selected,
            error_diagnostic = { bg = "NONE", fg = dim },
            error_diagnostic_visible = { bg = "NONE", fg = dim },
            error_diagnostic_selected = selected,
            warning = { bg = "NONE", fg = dim },
            warning_visible = { bg = "NONE", fg = dim },
            warning_selected = selected,
            warning_diagnostic = { bg = "NONE", fg = dim },
            warning_diagnostic_visible = { bg = "NONE", fg = dim },
            warning_diagnostic_selected = selected,
            info = { bg = "NONE", fg = dim },
            info_visible = { bg = "NONE", fg = dim },
            info_selected = selected,
            info_diagnostic = { bg = "NONE", fg = dim },
            info_diagnostic_visible = { bg = "NONE", fg = dim },
            info_diagnostic_selected = selected,
            hint = { bg = "NONE", fg = dim },
            hint_visible = { bg = "NONE", fg = dim },
            hint_selected = selected,
            hint_diagnostic = { bg = "NONE", fg = dim },
            hint_diagnostic_visible = { bg = "NONE", fg = dim },
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
