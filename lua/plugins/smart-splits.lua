-- Ctrl+h/j/k/l moves between nvim splits, and crosses out of nvim into the
-- surrounding multiplexer when the cursor is already at the outermost split.
--
-- Replaces vim-tmux-navigator: that plugin only knew about tmux, so on Windows
-- the keys dead-ended at nvim's edge. smart-splits speaks tmux *and* WezTerm
-- (shelling out to `wezterm cli activate-pane-direction`), so the same four keys
-- behave identically inside WSL tmux and in a native WezTerm pane.
local ok, ss = pcall(require, "smart-splits")
if not ok then return end

ss.setup({
  -- Stop at the outermost edge rather than wrapping around to the far split;
  -- the multiplexer handoff is attempted first, so this only bites when there
  -- is no neighbouring tmux/WezTerm pane either.
  at_edge = "stop",
  -- Auto-detects tmux vs wezterm from $TMUX / $WEZTERM_PANE. Left explicit as
  -- documentation of what this config actually relies on.
  multiplexer_integration = nil,
})

-- WezTerm identifies the foreground process to decide whether C-h/j/k/l belongs
-- to nvim (see ~/.wezterm/tmux-mode.lua). That lookup fails when nvim runs one
-- process deeper than WezTerm can see — inside WSL, or over ssh — because the
-- pane's foreground process is wsl.exe. Advertising a user var over OSC 1337
-- works in both cases. Wrapped for tmux passthrough (the WSL ~/.tmux.conf sets
-- `allow-passthrough on`), otherwise tmux would eat the escape sequence.
local function set_user_var(name, value)
  local payload = string.format("\027]1337;SetUserVar=%s=%s\a", name, vim.base64.encode(value))
  if vim.env.TMUX then
    payload = "\027Ptmux;" .. payload:gsub("\027", "\027\027") .. "\027\\"
  end
  io.stdout:write(payload)
end

vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
  callback = function() pcall(set_user_var, "IS_NVIM", "true") end,
})
vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
  callback = function() pcall(set_user_var, "IS_NVIM", "false") end,
})

vim.keymap.set("n", "<C-h>", ss.move_cursor_left,  { desc = "Window/pane left"  })
vim.keymap.set("n", "<C-j>", ss.move_cursor_down,  { desc = "Window/pane down"  })
vim.keymap.set("n", "<C-k>", ss.move_cursor_up,    { desc = "Window/pane up"    })
vim.keymap.set("n", "<C-l>", ss.move_cursor_right, { desc = "Window/pane right" })

-- Terminal-mode nav. Exit terminal mode explicitly before moving — Claude/omp
-- treat a <cmd> mapping as raw text and would leak it into the prompt.
local function term_nav(move)
  return function()
    vim.cmd("stopinsert")
    move()
  end
end
vim.keymap.set("t", "<C-h>", term_nav(ss.move_cursor_left),  { desc = "Window/pane left"  })
vim.keymap.set("t", "<C-j>", term_nav(ss.move_cursor_down),  { desc = "Window/pane down"  })
vim.keymap.set("t", "<C-k>", term_nav(ss.move_cursor_up),    { desc = "Window/pane up"    })
vim.keymap.set("t", "<C-l>", term_nav(ss.move_cursor_right), { desc = "Window/pane right" })

-- Terminal-mode nav: the global <C-h/j/k/l> t-maps above navigate out of ANY
-- terminal. In AI/chat terminals (claudecode, omp) we keep <C-j/k/l> raw so the
-- inner app receives them, but leave <C-h> on the global map so you can step
-- LEFT out of the AI pane into the editor (and across the multiplexer edge —
-- move_cursor_left falls through to tmux/WezTerm when nvim doesn't move). The
-- Claude pane is the right-most split, so left is the only direction with a
-- neighbour anyway; <C-h> (ASCII BS) is the most expendable inner-app key since
-- the real Backspace still works. Plain shells keep all four global nav maps.
-- To leave an AI buffer up/down/right: <C-\><C-n> then Ctrl+j/k/l.
-- NB: TermOpen (not FileType=toggleterm) — claudecode's terminal has no
-- toggleterm filetype, so a FileType autocmd never fired for it.
vim.api.nvim_create_autocmd("TermOpen", {
    callback = function(ev)
        vim.defer_fn(function()
            if not vim.api.nvim_buf_is_valid(ev.buf) then return end
            local name = vim.api.nvim_buf_get_name(ev.buf) or ""
            local cmd  = vim.b[ev.buf].terminal_job_cmd or ""
            local is_ai = (name .. " " .. cmd):lower():match("claude")
                or (name .. " " .. cmd):lower():match("omp")
            if not is_ai then return end -- plain shell: the global nav maps are correct
            -- AI panel: shadow the global nav maps for <C-j/k/l> so the inner app
            -- gets them. <C-h> is deliberately NOT shadowed — it keeps the global
            -- move_cursor_left map so you can step left out of the AI pane.
            local opts = { buffer = ev.buf, silent = true }
            for _, k in ipairs({ "<C-j>", "<C-k>", "<C-l>" }) do
                vim.keymap.set("t", k, k, opts) -- literal passthrough to the terminal job
            end
        end, 50)
    end,
})
