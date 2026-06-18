local opt                        = vim.opt

opt.number                       = true
opt.relativenumber               = true
opt.mouse                        = "a"
opt.clipboard                    = "unnamedplus"
opt.expandtab                    = true
opt.shiftwidth                   = 4
opt.tabstop                      = 4
opt.smartindent                  = true
opt.wrap                         = false
opt.ignorecase                   = true
opt.smartcase                    = true
opt.termguicolors                = true
opt.signcolumn                   = "yes"
opt.updatetime                   = 250
opt.timeoutlen                   = 300
opt.splitright                   = true
opt.splitbelow                   = true
opt.equalalways                  = false -- don't re-equalize splits on open/close (keeps neo-tree/Claude pinned)
opt.confirm                      = true  -- `:q` on unsaved buffer prompts instead of erroring
opt.undofile                     = true  -- persistent undo across sessions
opt.undodir                      = vim.fn.stdpath("state") .. "/undo"
opt.list                         = true  -- show invisible chars
opt.listchars                    = { tab = "→ ", trail = "·", nbsp = "␣", extends = "›", precedes = "‹" }
opt.scrolloff                    = 8
opt.completeopt                  = { "menu", "menuone", "noselect", "popup", "noinsert", "fuzzy" }
opt.winborder                    = "rounded"
opt.fillchars                    = { eob = " " } -- hide the ~ on empty lines below the buffer
opt.numberwidth                  = 6 -- wider line-number column (default 4)
opt.cursorline                   = true -- enable cursorline so CursorLineNr highlight kicks in
opt.cursorlineopt                = "number" -- ...but only highlight the line number, not the whole line

-- Cursor shape per mode + a slow blink for every mode (a:), colored via the
-- Cursor/lCursor highlight groups (set in config/autocmds.lua to the Ghostty
-- trailing-cursor accent — palette 4 of the current Omarchy theme).
opt.guicursor                    = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,"
  .. "a:blinkwait700-blinkon700-blinkoff700-Cursor/lCursor"

-- vim-tmux-navigator: suppress its built-in <C-h/j/k/l> mappings (incl. the
-- terminal-mode ones that leak "TmuxNavigateLeft" into Claude/omp).
-- Must be set BEFORE the plugin's plugin/ script runs — options.lua loads
-- before lua/plugins.
vim.g.tmux_navigator_no_mappings = 1

-- Disable netrw so oil.nvim handles directory paths (e.g. `nvim .`).
-- Must be set BEFORE plugins load.
vim.g.loaded_netrw               = 1
vim.g.loaded_netrwPlugin         = 1
