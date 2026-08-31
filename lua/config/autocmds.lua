-- ---------------------------------------------------------------------------
-- Omarchy theme sync
--
-- Omarchy writes the active theme name to ~/.config/omarchy/current/theme.name
-- (the sibling `theme` is a directory, not a file — common pitfall).
-- We map that name to a nvim colorscheme + background and apply both.
-- Themes without a mapping fall back to catppuccin / dark.
-- ---------------------------------------------------------------------------
local omarchy_to_nvim = {
    ["catppuccin"] = { colorscheme = "catppuccin", bg = "dark" },
    ["catppuccin-latte"] = { colorscheme = "catppuccin-latte", bg = "light" },
    ["tokyo-night"] = { colorscheme = "tokyonight-night", bg = "dark" },
    ["kanagawa"] = { colorscheme = "kanagawa", bg = "dark" },
    ["rose-pine"] = { colorscheme = "rose-pine", bg = "dark" },
    ["gruvbox"] = { colorscheme = "gruvbox", bg = "dark" },
    ["everforest"] = { colorscheme = "everforest", bg = "dark" },
    ["nord"] = { colorscheme = "nord", bg = "dark" },
    ["dracula"] = { colorscheme = "dracula", bg = "dark" },
    ["flexoki-light"] = { colorscheme = "catppuccin-latte", bg = "light" },
    ["space-monkey"] = { colorscheme = "monokai-pro", bg = "dark" },
}

local fallback = { colorscheme = "catppuccin", bg = "dark" }

-- Omarchy's "quattro" upgrade (2026-08-23) relocated live state from
-- ~/.config/omarchy/current (now gone) to ~/.local/state/omarchy/current.
-- Reading the old path fails SILENTLY -> nvim sat on its catppuccin fallback
-- for every theme. Probe new-then-old. Returns "" off Omarchy / on Windows
-- (os_homedir() is portable; os.getenv("HOME") is nil on Windows).
local function omarchy_current()
    local home = vim.uv.os_homedir() or ""
    for _, base in ipairs({ home .. "/.local/state/omarchy/current", home .. "/.config/omarchy/current" }) do
        if vim.uv.fs_stat(base) then
            return base
        end
    end
    return ""
end

local applied_theme -- last Omarchy theme name we actually applied
local function sync_os_theme()
    -- os.getenv("HOME") is nil on Windows; concatenating it threw and aborted the
    -- rest of init.lua (config.keymaps never loaded). os_homedir() is portable and
    -- the io.open simply misses on any box without Omarchy, landing on `fallback`.
    local base = omarchy_current()
    local handle = base ~= "" and io.open(base .. "/theme.name", "r") or nil
    local name = handle and handle:read("*l") or ""
    if handle then
        handle:close()
    end

    local choice = omarchy_to_nvim[name] or fallback

    -- Skip re-applies when the Omarchy theme hasn't changed. This runs on every
    -- FocusGained; re-running :colorscheme does `hi clear` + rebuild, which wipes
    -- dynamically-derived highlights (devicons icons, lualine/bufferline pills)
    -- and blanks the statusline. Gate only on the Omarchy theme name we control.
    -- Do NOT also compare `vim.g.colors_name == choice.colorscheme`: colorschemes
    -- rename themselves (catppuccin -> "catppuccin-mocha", "monokai-pro",
    -- "tokyonight-night"), so that clause never matched and we reloaded on EVERY
    -- focus. The `and vim.g.colors_name` is a heal-on-unset escape hatch: if the
    -- startup colorscheme apply failed (colors_name nil), a later focus re-applies.
    if name == applied_theme and vim.g.colors_name then
        return
    end
    applied_theme = name
    vim.opt.background = choice.bg
    pcall(vim.cmd.colorscheme, choice.colorscheme) -- guarded: missing plugin shouldn't crash startup
end

sync_os_theme()
-- nested = true: when FocusGained detects a GENUINE theme change and runs
-- :colorscheme, the ColorScheme autocmds that repaint dynamically-derived
-- highlights (devicons icons, lualine/bufferline pills, line numbers, cursor,
-- transparency) must fire. Autocmds don't fire autocmds unless the triggering
-- one is nested (:h autocmd-nested); without this `hi clear` wipes those groups
-- and nothing repaints. The reload only fires ColorScheme + OptionSet, neither
-- of which re-enters FocusGained, so there is no recursion.
vim.api.nvim_create_autocmd("FocusGained", { nested = true, callback = sync_os_theme })

vim.api.nvim_create_user_command("ThemeReload", sync_os_theme, { desc = "Re-read Omarchy theme and re-apply" })

-- Live watcher: re-applies the theme as soon as Omarchy writes theme.name.
-- Omarchy's stock `theme-set` hook only pokes zsh/tmux (no RPC to nvim), so
-- we self-watch the file via libuv. Re-arm after each event because the
-- file may be replaced via rename, breaking the original fs_event handle.
-- Skipped when the file doesn't exist (any non-Omarchy box, e.g. Windows):
-- fs_event:start on a missing path errors, and there is nothing to watch.
local theme_file = (function()
    local base = omarchy_current()
    return base ~= "" and (base .. "/theme.name") or ""
end)()
local fs_handle
local function watch_theme_file()
    if vim.fn.filereadable(theme_file) ~= 1 then
        return
    end
    if fs_handle then
        pcall(function()
            fs_handle:close()
        end)
    end
    fs_handle = vim.uv.new_fs_event()
    fs_handle:start(
        theme_file,
        {},
        vim.schedule_wrap(function(err)
            if err then
                return
            end
            sync_os_theme()
            vim.defer_fn(watch_theme_file, 100) -- re-arm
        end)
    )
end
watch_theme_file()

-- ---------------------------------------------------------------------------
-- Line-number coloring (muted for inactive lines, bold accent for current)
-- Re-applied on ColorScheme so it survives Omarchy theme switches.
-- ---------------------------------------------------------------------------
local function style_line_numbers()
    vim.api.nvim_set_hl(0, "LineNr", { fg = "#6c7086" }) -- subtle gray
    vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#f9e2af", bold = true }) -- bright yellow + bold
end

style_line_numbers()
vim.api.nvim_create_autocmd("ColorScheme", { callback = style_line_numbers })

-- ---------------------------------------------------------------------------
-- Window separator (the │ between splits, e.g. neo-tree | editor).
-- Many colorschemes `link WinSeparator Normal`, which paints the glyph in the
-- foreground colour -- a bright white hairline. And when an Omarchy theme
-- switch half-applies (colorscheme not installed -> partial :hi clear), the
-- separator is one of the first things to go bright. Pin it to a dim grey,
-- re-applied on ColorScheme like the line numbers above.
-- ---------------------------------------------------------------------------
local function style_separators()
  for _, g in ipairs({ "WinSeparator", "VertSplit" }) do
    vim.api.nvim_set_hl(0, g, { fg = "#313244", bg = "NONE" })  -- dim, no fill
  end
end

style_separators()
vim.api.nvim_create_autocmd("ColorScheme", { callback = style_separators })

-- ---------------------------------------------------------------------------
-- Comment coloring for yaml (and the bash injected into its `script:` blocks).
-- nvim-treesitter's yaml injections.scm runs the bash parser over run/script
-- block scalars, so `#` lines in an Azure Pipelines `script: |` are
-- @comment.bash, not @comment.yaml. catppuccin mocha puts Comment (#9399b2) on
-- the same lavender-grey axis as Normal text (#cdd6f4), so at terminal font
-- size comments stop reading as comments. Shift them to green-grey + italic.
-- Only the language-scoped captures are set (nvim resolves @<capture>.<lang>
-- before falling back to @<capture>), so C#/Lua comments keep the theme's own
-- color. Re-applied on ColorScheme, same as style_line_numbers above.
-- ---------------------------------------------------------------------------
local function style_comments()
    local fg = vim.o.background == "light" and "#4c6b52" or "#7f9f7f"
    for _, group in ipairs({ "@comment.yaml", "@comment.bash" }) do
        vim.api.nvim_set_hl(0, group, { fg = fg, italic = true })
    end
end

style_comments()
vim.api.nvim_create_autocmd("ColorScheme", { callback = style_comments })

-- ---------------------------------------------------------------------------
-- Theme accent: `palette = 4` of the active Omarchy theme's ghostty.conf —
-- the same value Ghostty's trailing-cursor animation is baked from (see
-- ~/.config/omarchy/hooks/generate-cursor-trail). Shared by the cursor and
-- the markdown Visual emphasis below.
-- ---------------------------------------------------------------------------
local function read_omarchy_accent()
    -- os_homedir() not os.getenv("HOME"): the latter is nil on Windows and the
    -- concat aborted init.lua. Off Omarchy the open just misses -> fallback accent.
    local base = omarchy_current()
    local f = base ~= "" and io.open(base .. "/theme/ghostty.conf", "r") or nil
    if f then
        for line in f:lines() do
            local hex = line:match("^palette%s*=%s*4=#?(%x%x%x%x%x%x)")
            if hex then
                f:close()
                return "#" .. hex
            end
        end
        f:close()
    end
    return "#7e9cd8" -- fallback to kanagawa accent
end

-- ---------------------------------------------------------------------------
-- Cursor color synced to the Ghostty trailing-cursor animation (same accent
-- as above). Re-applied on ColorScheme so an Omarchy theme switch keeps them
-- in sync. Blink is set via guicursor in config/options.lua.
-- ---------------------------------------------------------------------------
local function style_cursor()
    local accent = read_omarchy_accent()
    vim.api.nvim_set_hl(0, "Cursor", { fg = "#1e1e2e", bg = accent })
    vim.api.nvim_set_hl(0, "lCursor", { fg = "#1e1e2e", bg = accent })
end

style_cursor()
vim.api.nvim_create_autocmd("ColorScheme", { callback = style_cursor })

-- ---------------------------------------------------------------------------
-- Transparent background: clear the bg of every "this is the editor surface"
-- highlight group so the wallpaper bleeds straight through every cell.
--
-- Why so aggressive: Ghostty has an open opacity-stacking bug
-- (ghostty-org/ghostty#8642) where cells with explicit colored bg render
-- more opaque than default-bg cells under `background-opacity`. To get the
-- uniform see-through look the in-tmux nvim has (where tmux flattens every
-- cell to default-bg, sidestepping the bug), we have to strip the bg of as
-- many colored chrome groups as possible here. Visual / Search / NormalFloat
-- intentionally stay painted so selections, search hits, and popups remain
-- readable.
-- Re-applied on ColorScheme so theme switches don't repaint a bg back.
-- ---------------------------------------------------------------------------
local TRANSPARENT_GROUPS = {
    -- editor surface
    "Normal",
    "NormalNC",
    "SignColumn",
    "EndOfBuffer",
    "MsgArea",
    "VertSplit",
    "WinSeparator",
    "StatusLine",
    "StatusLineNC",
    "LineNr",
    "CursorLineNr",
    "CursorLine",
    "CursorColumn",
    "FoldColumn",
    "Folded",
    -- tabline / winbar (lualine/bufferline groups handled via pattern below)
    "TabLine",
    "TabLineFill",
    "TabLineSel",
    "WinBar",
    "WinBarNC",
    -- sidebars
    "TelescopeNormal",
    "TelescopeBorder",
    "NeoTreeNormal",
    "NeoTreeNormalNC",
    "NeoTreeEndOfBuffer",
}

-- Highlight groups created dynamically (bufferline etc.) can't be listed
-- by name. Strip their bg by name-pattern after each ColorScheme.
-- `^lualine_` is stripped everywhere: the statusline is a foreground-only
-- design (see plugins/lualine.lua) because Ghostty's opacity-stacking bug
-- (ghostty#7957, unfixed as of 1.3.1) mangles explicit-bg cells outside
-- tmux. Stripping in both contexts keeps tmux and plain nvim identical.
-- ^BufferLine is NOT stripped here: plugins/bufferline.lua owns every
-- BufferLine bg explicitly (transparent bar + filled pill on the active tab).
local TRANSPARENT_PATTERNS = {
    "^TabLine",
    "^WinBar",
    "^lualine_",
}

-- Toggleable at runtime (<leader>ut). When off, make_transparent() no-ops so
-- the colorscheme's own backgrounds survive; turning it back on re-strips them.
-- Default OFF: opaque backgrounds + filled lualine pills (plugins/lualine.lua).
vim.g.transparent_enabled = false

local function make_transparent()
    if not vim.g.transparent_enabled then
        return
    end
    for _, g in ipairs(TRANSPARENT_GROUPS) do
        pcall(
            vim.api.nvim_set_hl,
            0,
            g,
            vim.tbl_extend("force", vim.api.nvim_get_hl(0, { name = g }) or {}, { bg = "NONE", ctermbg = "NONE" })
        )
    end
    for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
        for _, pat in ipairs(TRANSPARENT_PATTERNS) do
            if name:match(pat) then
                pcall(
                    vim.api.nvim_set_hl,
                    0,
                    name,
                    vim.tbl_extend(
                        "force",
                        vim.api.nvim_get_hl(0, { name = name }) or {},
                        { bg = "NONE", ctermbg = "NONE" }
                    )
                )
                break
            end
        end
    end
end

make_transparent()
vim.api.nvim_create_autocmd("ColorScheme", { callback = make_transparent })
-- lualine/bufferline call vim.api.nvim_set_hl after ColorScheme to install
-- their own dynamic groups, so re-run on a few extra events that fire after
-- those finish (BufEnter is the cheapest one that catches lualine refreshes).
vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, { callback = make_transparent })

-- Toggle transparency on/off. Off => reload the colorscheme to repaint its
-- backgrounds (the ColorScheme autocmd re-runs make_transparent, which no-ops
-- while disabled). On => strip chrome backgrounds again immediately.
local function toggle_transparency()
    vim.g.transparent_enabled = not vim.g.transparent_enabled
    if vim.g.transparent_enabled then
        make_transparent()
    elseif vim.g.colors_name then
        vim.cmd.colorscheme(vim.g.colors_name) -- repaint opaque backgrounds
    end
    vim.notify("Transparency " .. (vim.g.transparent_enabled and "ON" or "OFF"))
end

vim.keymap.set("n", "<leader>ut", toggle_transparency, { desc = "Toggle transparent background" })

-- ---------------------------------------------------------------------------
-- Markdown presenting: while a visual mode (v / V / ctrl-v) is active in a
-- markdown buffer, the selection is bold white on the theme's own Visual
-- background and the
-- REST of the window keeps its original colors, slightly darker — subtle
-- spotlight for walking someone through a document. Terminal cells are
-- fixed-size, so "bigger" is faked with bold weight.
--
-- Mechanism: the window is swapped onto a highlight namespace where every
-- group's fg is scaled by DIM_FACTOR (a flat grey overlay killed the theme's
-- colors) and `Visual` itself is redefined bright. Visual must live IN the
-- namespace: nvim_win_set_hl_ns takes precedence over 'winhighlight', so a
-- winhl Visual:X mapping is ignored while the namespace is active. The dim
-- namespace is built lazily (one pass over all global groups) and invalidated
-- on ColorScheme so an Omarchy theme switch rebuilds it from the new colors.
-- Groups with a link are re-linked inside the namespace so they resolve to
-- the darkened target; groups without an fg are skipped (namespace lookup
-- falls back to the identical global definition). Non-markdown windows never
-- get the namespace, so their Visual stays the theme's own.
-- ---------------------------------------------------------------------------
local DIM_FACTOR = 0.5 -- non-selected fg scales to this fraction of the original
local dim_ns = vim.api.nvim_create_namespace("markdown_present_dim")
local dim_ns_built = false

local function darken(color)
    local r = math.floor(math.floor(color / 65536) * DIM_FACTOR)
    local g = math.floor(math.floor(color / 256) % 256 * DIM_FACTOR)
    local b = math.floor((color % 256) * DIM_FACTOR)
    return r * 65536 + g * 256 + b
end

local function build_dim_ns()
    for name, attrs in pairs(vim.api.nvim_get_hl(0, {})) do
        if attrs.link then
            pcall(vim.api.nvim_set_hl, dim_ns, name, { link = attrs.link })
        elseif attrs.fg then
            local copy = vim.tbl_extend("force", {}, attrs)
            copy.fg = darken(copy.fg)
            pcall(vim.api.nvim_set_hl, dim_ns, name, copy)
        end
    end
    -- the selection must stay bright inside the dim namespace (overwrites the
    -- darkened copy of the theme's Visual made by the loop above): bold white
    -- text on the theme's own (undimmed) Visual background
    local visual = vim.api.nvim_get_hl(0, { name = "Visual", link = false })
    vim.api.nvim_set_hl(dim_ns, "Visual", { fg = "#ffffff", bg = visual.bg or read_omarchy_accent(), bold = true })
    dim_ns_built = true
end

vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
        dim_ns_built = false
    end,
})

-- One catch-all ModeChanged handler instead of enter/leave patterns: a switch
-- between visual modes (v -> V) matches both an enter and a leave pattern and
-- their firing order would undo the dim we just applied.
vim.api.nvim_create_autocmd("ModeChanged", {
    callback = function(ev)
        local win = vim.api.nvim_get_current_win()
        local new_mode = ev.match:match(":(.*)$") or ""
        if vim.bo.filetype == "markdown" and new_mode:match("^[vV\22]") then
            if not dim_ns_built then
                build_dim_ns()
            end
            vim.api.nvim_win_set_hl_ns(win, dim_ns)
        else
            vim.api.nvim_win_set_hl_ns(win, 0)
        end
    end,
})

-- ---------------------------------------------------------------------------
-- Briefly highlight yanked text so you can see what was copied
-- ---------------------------------------------------------------------------
vim.api.nvim_set_hl(0, "YankFlash", { bg = "#fab387", fg = "#1e1e2e", bold = true })
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight on yank",
    callback = function()
        vim.hl.on_yank({ higroup = "YankFlash", timeout = 150 })
    end,
})

-- ---------------------------------------------------------------------------
-- Weekly-notes folding: each `## Day` collapses to one fold so only today's
-- section is open by default. Scoped to ~/Documents/notes/*-W*.md so general
-- markdown folding (treesitter) stays untouched.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = vim.fn.expand("~/Documents/notes") .. "/*-W*.md",
    callback = function()
        require("util.weekly-notes").setup_folds()
    end,
})
