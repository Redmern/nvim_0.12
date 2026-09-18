-- Route to the right account by folder: the wrapper picks CLAUDE_CONFIG_DIR
-- from the working directory (~/work -> work account, else personal).
-- Windows has no such wrapper, so `claude` on PATH it is — but see below.
local profile_wrapper = vim.fn.expand("$HOME/.local/bin/claude-profile")
local claude_cmd = vim.fn.executable(profile_wrapper) == 1 and profile_wrapper or "claude"

-- Windows account routing. claudecode spawns claude as a direct child of nvim,
-- so it inherits nvim's environment and misses both Windows hooks: the
-- PowerShell `claude` function (only wraps launches typed in pwsh) and the
-- cmd.exe AutoRun hook at ~\.claude-profile-hook.cmd (only cmd.exe sessions,
-- which is what fleet spawns go through). Set the variable here instead.
if vim.fn.has("win32") == 1 then
  -- lowercase root, no trailing separator -> config dir. This list is duplicated
  -- in $ClaudeProfileRoots (PowerShell profile) and ~\.claude-profile-hook.cmd;
  -- change one, change all three.
  local roots = { ["c:\\personal"] = (vim.env.USERPROFILE or "") .. "\\.claude-personal" }

  -- Anything already in the environment was set deliberately (a `personal`
  -- wezterm window, an explicit export) and outranks the folder rules.
  local inherited = vim.env.CLAUDE_CONFIG_DIR

  local function apply_account_profile()
    if inherited then
      return
    end
    local cwd = (vim.fn.getcwd() or ""):gsub("/", "\\"):lower()
    for root, dir in pairs(roots) do
      if cwd == root or cwd:sub(1, #root + 1) == root .. "\\" then
        vim.env.CLAUDE_CONFIG_DIR = dir
        return
      end
    end
    vim.env.CLAUDE_CONFIG_DIR = nil -- default profile: work account
  end

  apply_account_profile()
  vim.api.nvim_create_autocmd("DirChanged", { callback = apply_account_profile })
end

-- Windows: claudecode.nvim picks its port by test-binding a probe socket in
-- find_available_port(), closing it, then binding that same port for real in
-- create_server(). libuv closes handles asynchronously and Windows binds with
-- SO_EXCLUSIVEADDRUSE, so the probe can still own the port when the real
-- listen() lands -> "Failed to listen on port N: EADDRINUSE" at init.
-- Retry: each attempt re-rolls a random port, and vim.wait pumps the event
-- loop so the previous probe handle is actually reaped in between.
if vim.fn.has("win32") == 1 then
  local tcp = require("claudecode.server.tcp")
  local create_server = tcp.create_server
  tcp.create_server = function(config, callbacks, auth_token)
    local server, err
    for attempt = 1, 5 do
      server, err = create_server(config, callbacks, auth_token)
      if server then
        return server, nil
      end
      if attempt < 5 then
        vim.wait(25)
      end
    end
    return nil, err
  end
end

require("claudecode").setup({
  terminal_cmd = claude_cmd,
  -- Spawn Claude in nvim's project cwd so the wrapper sees the right folder.
  cwd_provider = function(ctx)
    return ctx.cwd
  end,
  terminal = {
    show_native_term_exit_tip = false,
    -- pin the split geometry so it never depends on which window happens to
    -- be focused when the terminal opens
    split_side = "right",
    split_width_percentage = 0.30,
  },
})

-- Toggling Claude while focus sits in neo-tree (or another side panel) makes
-- the split land relative to the wrong window — sometimes consuming the
-- tree, sometimes opening a sliver. Always jump to the main editor window
-- first, then re-assert the tree's width once the split has landed.
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

local function claude_toggle()
  -- toggling from inside the claude terminal itself just closes it
  if vim.bo.buftype ~= "terminal" then
    local main = main_window()
    if main then vim.api.nvim_set_current_win(main) end
  end
  vim.cmd("ClaudeCode")
  vim.defer_fn(function()
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree" then
        vim.api.nvim_win_set_width(w, 45)
        vim.wo[w].winfixwidth = true
      end
    end
  end, 80)
end

-- <leader>c* — Claude Code (icons attached via which-key.add below)
vim.keymap.set({ "n", "t" }, "<leader>cc", claude_toggle, { desc = "Toggle Claude Code" })
vim.keymap.set("n", "<leader>cf", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude Code" })
-- Send the visual selection to Claude. Uses the `:`-range form (not <cmd>…):
-- pressing `:` from visual mode inserts `'<,'>` and leaves visual mode, so the
-- command runs in normal mode with an explicit range and hits ClaudeCodeSend's
-- clean normal path — no visual-exit feedkeys dance, no terminal focus-steal.
-- Lives on <leader>cs (the Claude group) instead of <leader>s, which collides
-- with grug-far's "Search/Replace" group (<leader>sR) and got shadowed by the
-- which-key menu (the "press it twice / screen blanks / hit esc" symptom).
vim.keymap.set("v", "<leader>cs", ":ClaudeCodeSend<cr>", { silent = true, desc = "Send selection to Claude" })
vim.keymap.set("n", "<leader>ca", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add current file to context" })

-- Pin every narrow terminal split (claudecode/omp side panels).
-- Fired on multiple events because claudecode opens via snacks.terminal which
-- doesn't always trigger TermOpen at a useful time.
local function pin_narrow_term(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then return end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "terminal" then return end
  if vim.api.nvim_win_get_width(win) < math.floor(vim.o.columns * 0.8) then
    vim.wo[win].winfixwidth = true
  end
end

vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter", "WinEnter" }, {
  callback = function() pin_narrow_term(vim.api.nvim_get_current_win()) end,
})

require("which-key").add({
  { "<leader>cc", icon = { icon = "󰭹", color = "purple" }, mode = { "n", "t" } },
  { "<leader>cf", icon = { icon = "󰈶", color = "purple" } },
  { "<leader>ca", icon = { icon = "󰐕", color = "green" } },
  { "<leader>cs", icon = { icon = "󰒡", color = "blue" }, mode = "v" },
})
