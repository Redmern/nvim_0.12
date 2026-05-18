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

-- Omarchy's ~/.config/omarchy/hooks/theme-set sends :ThemeReload over RPC to
-- every running nvim instance, so theme changes apply live (no focus needed).
vim.api.nvim_create_user_command("ThemeReload", sync_os_theme, { desc = "Re-read Omarchy theme and re-apply" })

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
-- Briefly highlight yanked text so you can see what was copied
-- ---------------------------------------------------------------------------
vim.api.nvim_set_hl(0, "YankFlash", { bg = "#fab387", fg = "#1e1e2e", bold = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight on yank",
  callback = function()
    vim.hl.on_yank({ higroup = "YankFlash", timeout = 150 })
  end,
})
