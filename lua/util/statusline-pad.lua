-- One-row empty "spacer" window pinned to the bottom of the layout, directly
-- above the global statusline (laststatus=3). Gives lualine visual top
-- padding the way tmux's empty status-format[1] row pads its bar — nvim has
-- no native statusline padding, so this fakes it with a real window.
--
-- Invariants handled here:
--   * pad never takes focus (WinEnter bounces back; quitting the last real
--     window quits nvim instead of stranding you in the pad)
--   * pad is re-pinned to the bottom if another split lands below it
--   * pad is invisible: transparent, no number/sign/fold columns, no eob ~
local M = {}

local PAD_FT = "statusline-pad"
local pad_win, pad_buf

local function pad_valid()
  return pad_win ~= nil and vim.api.nvim_win_is_valid(pad_win)
end

local function ensure_buf()
  if pad_buf and vim.api.nvim_buf_is_valid(pad_buf) then return pad_buf end
  pad_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[pad_buf].buftype = "nofile"
  vim.bo[pad_buf].bufhidden = "hide"
  vim.bo[pad_buf].swapfile = false
  vim.bo[pad_buf].filetype = PAD_FT
  return pad_buf
end

local function create()
  if pad_valid() then return end
  local cur = vim.api.nvim_get_current_win()
  vim.api.nvim_set_hl(0, "StatuslinePad", { bg = "NONE" })
  vim.cmd("noautocmd botright 1split")
  pad_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(pad_win, ensure_buf())
  vim.api.nvim_win_set_height(pad_win, 1)
  local wo = vim.wo[pad_win]
  wo.winfixheight = true
  wo.number = false
  wo.relativenumber = false
  wo.cursorline = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.fillchars = "eob: "
  wo.winhighlight = table.concat({
    "Normal:StatuslinePad",
    "NormalNC:StatuslinePad",
    "EndOfBuffer:StatuslinePad",
    "CursorLine:StatuslinePad",
    "WinSeparator:StatuslinePad",
  }, ",")
  vim.w[pad_win].statusline_pad = true
  if vim.api.nvim_win_is_valid(cur) then vim.api.nvim_set_current_win(cur) end
end

-- pad must be the bottom-most window; if some split ended up below it (e.g.
-- a botright toggleterm), recreate it at the true bottom.
local function misplaced()
  if not pad_valid() then return false end
  if vim.api.nvim_win_get_height(pad_win) ~= 1 then return true end
  -- full-height vsplits opened later (claudecode, neo-tree) steal the pad's
  -- row in their column; a recreated botright split spans everything again
  if vim.api.nvim_win_get_width(pad_win) ~= vim.o.columns then return true end
  local pad_row = vim.api.nvim_win_get_position(pad_win)[1]
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= pad_win and vim.api.nvim_win_get_config(w).relative == "" then
      if vim.api.nvim_win_get_position(w)[1] > pad_row then return true end
    end
  end
  return false
end

local scheduled = false
local function enforce()
  if scheduled then return end
  scheduled = true
  vim.schedule(function()
    scheduled = false
    if vim.v.exiting ~= vim.NIL then return end
    if not pad_valid() then
      create()
    elseif misplaced() then
      pcall(vim.api.nvim_win_close, pad_win, true)
      pad_win = nil
      create()
    end
  end)
end

function M.setup()
  -- don't let sessions persist the (blank) pad window
  vim.opt.sessionoptions:remove("blank")

  local group = vim.api.nvim_create_augroup("statusline_pad", { clear = true })

  vim.api.nvim_create_autocmd("VimEnter", { group = group, callback = enforce })
  vim.api.nvim_create_autocmd({ "WinNew", "WinClosed", "VimResized", "TabEnter", "SessionLoadPost" }, {
    group = group,
    callback = enforce,
  })

  -- keep focus out of the pad; if it's the last window standing, just quit
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if not vim.w.statusline_pad then return end
      if #vim.api.nvim_tabpage_list_wins(0) == 1 then
        vim.cmd("silent! quit")
      else
        vim.cmd("wincmd p")
      end
    end,
  })

  -- transparency strip can run before this module defines the group
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function() vim.api.nvim_set_hl(0, "StatuslinePad", { bg = "NONE" }) end,
  })
end

return M
