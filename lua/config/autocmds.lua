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
}

local fallback = { colorscheme = "catppuccin", bg = "dark" }

local function sync_os_theme()
  local handle = io.open(os.getenv("HOME") .. "/.config/omarchy/current/theme.name", "r")
  local name = handle and handle:read("*l") or ""
  if handle then handle:close() end

  local choice = omarchy_to_nvim[name] or fallback
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
-- Transparent background: clear the bg of every "this is the editor surface"
-- highlight group. Floats keep their own bg (NormalFloat) so popups still pop.
-- Re-applied on ColorScheme so Omarchy theme switches don't repaint.
-- ---------------------------------------------------------------------------
local TRANSPARENT_GROUPS = {
  "Normal", "NormalNC",
  "SignColumn", "EndOfBuffer", "MsgArea", "VertSplit", "WinSeparator",
  "StatusLine", "StatusLineNC",
  "LineNr", "CursorLineNr",
  "FoldColumn",
  "TelescopeNormal", "TelescopeBorder",
  "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeEndOfBuffer",
}

local function make_transparent()
  for _, g in ipairs(TRANSPARENT_GROUPS) do
    pcall(vim.api.nvim_set_hl, 0, g, vim.tbl_extend("force",
      vim.api.nvim_get_hl(0, { name = g }) or {}, { bg = "NONE", ctermbg = "NONE" }))
  end
end

make_transparent()
vim.api.nvim_create_autocmd("ColorScheme", { callback = make_transparent })

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
