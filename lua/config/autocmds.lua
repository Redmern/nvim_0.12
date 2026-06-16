-- ---------------------------------------------------------------------------
-- Omarchy theme sync
--
-- Omarchy writes the active theme name to ~/.config/omarchy/current/theme.name
-- (the sibling `theme` is a directory, not a file — common pitfall).
-- We map that name to a nvim colorscheme + background and apply both.
-- Themes without a mapping fall back to catppuccin / dark.
-- ---------------------------------------------------------------------------
local omarchy_to_nvim = {
  ["catppuccin"]       = { colorscheme = "catppuccin",       bg = "dark"  },
  ["catppuccin-latte"] = { colorscheme = "catppuccin-latte", bg = "light" },
  ["tokyo-night"]      = { colorscheme = "tokyonight-night", bg = "dark"  },
  ["kanagawa"]         = { colorscheme = "kanagawa",         bg = "dark"  },
  ["rose-pine"]        = { colorscheme = "rose-pine",        bg = "dark"  },
  ["gruvbox"]          = { colorscheme = "gruvbox",          bg = "dark"  },
  ["everforest"]       = { colorscheme = "everforest",       bg = "dark"  },
  ["nord"]             = { colorscheme = "nord",             bg = "dark"  },
  ["dracula"]          = { colorscheme = "dracula",          bg = "dark"  },
  ["flexoki-light"]    = { colorscheme = "catppuccin-latte", bg = "light" },
  ["space-monkey"]     = { colorscheme = "monokai-pro",      bg = "dark"  },
}

local fallback = { colorscheme = "catppuccin", bg = "dark" }

local applied_theme -- last Omarchy theme name we actually applied
local function sync_os_theme()
  local handle = io.open(os.getenv("HOME") .. "/.config/omarchy/current/theme.name", "r")
  local name = handle and handle:read("*l") or ""
  if handle then handle:close() end

  local choice = omarchy_to_nvim[name] or fallback

  -- Skip redundant re-applies. This runs on every FocusGained; re-running
  -- :colorscheme does `hi clear` + rebuild, which races with lualine's own
  -- ColorScheme refresh and intermittently blanks the statusline pill
  -- backgrounds. Only re-apply when the theme actually changed.
  if name == applied_theme and vim.g.colors_name == choice.colorscheme then
    return
  end
  applied_theme = name
  vim.opt.background = choice.bg
  pcall(vim.cmd.colorscheme, choice.colorscheme) -- guarded: missing plugin shouldn't crash startup
end

sync_os_theme()
vim.api.nvim_create_autocmd("FocusGained", { callback = sync_os_theme })

vim.api.nvim_create_user_command("ThemeReload", sync_os_theme,
  { desc = "Re-read Omarchy theme and re-apply" })

-- Live watcher: re-applies the theme as soon as Omarchy writes theme.name.
-- Omarchy's stock `theme-set` hook only pokes zsh/tmux (no RPC to nvim), so
-- we self-watch the file via libuv. Re-arm after each event because the
-- file may be replaced via rename, breaking the original fs_event handle.
local theme_file = os.getenv("HOME") .. "/.config/omarchy/current/theme.name"
local fs_handle
local function watch_theme_file()
  if fs_handle then pcall(function() fs_handle:close() end) end
  fs_handle = vim.uv.new_fs_event()
  fs_handle:start(theme_file, {}, vim.schedule_wrap(function(err)
    if err then return end
    sync_os_theme()
    vim.defer_fn(watch_theme_file, 100) -- re-arm
  end))
end
watch_theme_file()

-- ---------------------------------------------------------------------------
-- Line-number coloring (muted for inactive lines, bold accent for current)
-- Re-applied on ColorScheme so it survives Omarchy theme switches.
-- ---------------------------------------------------------------------------
local function style_line_numbers()
  vim.api.nvim_set_hl(0, "LineNr",       { fg = "#6c7086" })                  -- subtle gray
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#f9e2af", bold = true })     -- bright yellow + bold
end

style_line_numbers()
vim.api.nvim_create_autocmd("ColorScheme", { callback = style_line_numbers })

-- ---------------------------------------------------------------------------
-- Cursor color synced to the Ghostty trailing-cursor animation.
-- That trail is baked from `palette = 4` (the accent) of the active theme's
-- ghostty.conf (see ~/.config/omarchy/hooks/generate-cursor-trail). We read
-- the same value so the nvim cursor matches it, and re-apply on ColorScheme
-- so an Omarchy theme switch keeps them in sync. Blink is set via guicursor
-- in config/options.lua.
-- ---------------------------------------------------------------------------
local function style_cursor()
  local accent
  local f = io.open(os.getenv("HOME") .. "/.config/omarchy/current/theme/ghostty.conf", "r")
  if f then
    for line in f:lines() do
      local hex = line:match("^palette%s*=%s*4=#?(%x%x%x%x%x%x)")
      if hex then accent = "#" .. hex break end
    end
    f:close()
  end
  accent = accent or "#7e9cd8" -- fallback to kanagawa accent
  vim.api.nvim_set_hl(0, "Cursor",  { fg = "#1e1e2e", bg = accent })
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
  "Normal", "NormalNC",
  "SignColumn", "EndOfBuffer", "MsgArea", "VertSplit", "WinSeparator",
  "StatusLine", "StatusLineNC",
  "LineNr", "CursorLineNr", "CursorLine", "CursorColumn",
  "FoldColumn", "Folded",
  -- tabline / winbar (lualine/bufferline groups handled via pattern below)
  "TabLine", "TabLineFill", "TabLineSel",
  "WinBar", "WinBarNC",
  -- sidebars
  "TelescopeNormal", "TelescopeBorder",
  "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeEndOfBuffer",
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
  if not vim.g.transparent_enabled then return end
  for _, g in ipairs(TRANSPARENT_GROUPS) do
    pcall(vim.api.nvim_set_hl, 0, g, vim.tbl_extend("force",
      vim.api.nvim_get_hl(0, { name = g }) or {}, { bg = "NONE", ctermbg = "NONE" }))
  end
  for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
    for _, pat in ipairs(TRANSPARENT_PATTERNS) do
      if name:match(pat) then
        pcall(vim.api.nvim_set_hl, 0, name, vim.tbl_extend("force",
          vim.api.nvim_get_hl(0, { name = name }) or {}, { bg = "NONE", ctermbg = "NONE" }))
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
-- Statusline top padding: 1-row spacer window pinned above the global
-- statusline (see lua/util/statusline-pad.lua). Disabled by preference — the
-- blank row above the bar wasn't wanted. Re-enable by uncommenting.
-- ---------------------------------------------------------------------------
-- require("util.statusline-pad").setup()

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
