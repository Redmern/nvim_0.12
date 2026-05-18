local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true
opt.wrap = true
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 8
opt.completeopt = { "menu", "menuone", "noselect", "popup", "noinsert", "fuzzy" }
opt.winborder = "rounded"
opt.fillchars = { eob = " " }   -- hide the ~ on empty lines below the buffer
opt.numberwidth = 6             -- wider line-number column (default 4)
opt.cursorline = true           -- enable cursorline so CursorLineNr highlight kicks in
opt.cursorlineopt = "number"    -- ...but only highlight the line number, not the whole line
