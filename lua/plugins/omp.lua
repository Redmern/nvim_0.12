-- omp — drive the `omp` CLI (oh-my-pi) in a managed terminal split.
-- Mirrors the <leader>c* Claude Code keymaps under <leader>o* (these replace the
-- old bindings that used to live here). omp has no nvim plugin yet, so this is a thin terminal
-- manager: toggle/focus a right-side split and chan_send selections / @-file
-- mentions straight into the omp TUI — the same trick fleet.nvim uses.

-- --allow-home: omp auto-switches OUT of a $HOME-rooted cwd to a temp dir unless
-- told not to. nvim's project cwd is usually under ~, so without this omp would
-- run blind to the project. :terminal inherits nvim's cwd otherwise.
local OMP_CMD = "omp --allow-home"
local SPLIT_WIDTH = 0.30

vim.o.autoread = true -- pick up edits omp makes on disk

local state = { buf = nil, win = nil, chan = nil }

local function term_valid()
  return state.buf and vim.api.nvim_buf_is_valid(state.buf)
end
local function win_valid()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end
local function chan_live()
  return term_valid() and vim.bo[state.buf].channel and vim.bo[state.buf].channel > 0
end

-- main editor window (skip neo-tree / side panels / the statusline pad) so the
-- split lands relative to the real editor, not a sliver panel. Mirror of the
-- helper in claudecode.lua.
local function main_window()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.api.nvim_win_get_config(w).relative == ""
        and vim.bo[b].buftype == ""
        and vim.bo[b].filetype ~= "neo-tree"
        and not vim.w[w].statusline_pad then
      return w
    end
  end
end

local function open()
  -- toggling from inside the omp terminal itself shouldn't reparent it
  if vim.bo.buftype ~= "terminal" then
    local main = main_window()
    if main then vim.api.nvim_set_current_win(main) end
  end
  vim.cmd("botright vsplit")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(state.win, math.floor(vim.o.columns * SPLIT_WIDTH))
  vim.wo[state.win].winfixwidth = true
  if chan_live() then
    vim.api.nvim_win_set_buf(state.win, state.buf) -- reuse the live session
  else
    vim.cmd("terminal " .. OMP_CMD)
    state.buf = vim.api.nvim_get_current_buf()
    state.chan = vim.bo[state.buf].channel
  end
  vim.cmd("startinsert")
end

local function close()
  if win_valid() then vim.api.nvim_win_close(state.win, false) end
  state.win = nil
end

local function toggle()
  if win_valid() then close() else open() end
end

local function focus()
  if win_valid() then
    vim.api.nvim_set_current_win(state.win)
  else
    open()
  end
  vim.cmd("startinsert")
end

-- Drop text into the omp prompt. Multi-line text is wrapped in bracketed-paste
-- markers so the TUI takes it as ONE paste instead of submitting on each
-- embedded newline. We deliberately do NOT send a trailing CR: the text lands
-- in the input and focus moves to omp so you can add a question and submit
-- yourself (matches "add to context", not "fire a turn").
local function send(text)
  local function deliver()
    local chan = vim.bo[state.buf].channel
    if not (chan and chan > 0) then return end
    if text:find("\n") then
      vim.api.nvim_chan_send(chan, "\27[200~" .. text .. "\27[201~")
    else
      vim.api.nvim_chan_send(chan, text)
    end
  end
  if chan_live() and win_valid() then
    focus()
    deliver()
  else
    open()
    vim.defer_fn(function() focus(); deliver() end, 400) -- let omp boot first
  end
end

local function relpath()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then return nil end
  return vim.fn.fnamemodify(name, ":.")
end

-- <leader>oa — add the current file to omp's context via an @-mention.
local function add_file()
  local p = relpath()
  if not p then
    vim.notify("omp: current buffer has no file", vim.log.levels.WARN)
    return
  end
  send("@" .. p .. " ")
end

-- <leader>os (visual) — send the selection, tagged with its file + line range.
local function send_selection()
  local a, b = vim.fn.getpos("v"), vim.fn.getpos(".")
  local lines = vim.fn.getregion(a, b, { type = vim.fn.mode() })
  if #lines == 0 then return end
  local l1, l2 = a[2], b[2]
  if l1 > l2 then l1, l2 = l2, l1 end
  local header = relpath() and string.format("@%s (lines %d-%d):\n", relpath(), l1, l2) or ""
  send(header .. table.concat(lines, "\n"))
end

-- <leader>o* — omp (icons via which-key.add below), mirroring the <leader>c* set
vim.keymap.set({ "n", "t" }, "<leader>oo", toggle, { desc = "Toggle omp" })
vim.keymap.set("n", "<leader>of", focus, { desc = "Focus omp" })
vim.keymap.set("n", "<leader>oa", add_file, { desc = "Add current file to omp" })
vim.keymap.set("x", "<leader>os", send_selection, { desc = "Send selection to omp" })

require("which-key").add({
  { "<leader>oo", icon = { icon = "󰭹", color = "orange" }, mode = { "n", "t" } },
  { "<leader>of", icon = { icon = "󰈶", color = "orange" } },
  { "<leader>oa", icon = { icon = "󰐕", color = "green" } },
  { "<leader>os", icon = { icon = "󰒡", color = "blue" }, mode = "x" },
})
