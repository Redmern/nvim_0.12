-- Horizontal split (never auto-closes on focus loss). The "rounded border"
-- is faked via a winbar with a top corner line — gives the look without the
-- float-window close-on-wincmd quirk.
-- Open the terminal in whatever shell nvim was actually launched from, rather
-- than nvim's `shell` option. On Windows that option is cmd.exe (nvim's default,
-- since $SHELL only exists inside a POSIX shell), so Ctrl+/ used to drop into
-- cmd with no PowerShell profile loaded.
--
-- `vim.o.shell` is deliberately left alone: lua/util/dotnet-debug.lua and `:!`
-- depend on cmd semantics, and changing it would mean changing the whole
-- shellcmdflag/shellquote/shellxquote/shellpipe/shellredir set with it.
--
-- On Windows the parent process is the only reliable signal — $SHELL is absent
-- under pwsh/cmd, and when Git Bash does set it, it holds a POSIX path that
-- cmd.exe cannot execute. Elsewhere (Linux, WSL, Arch) $SHELL is authoritative.
local resolved_shell

-- Parent image name -> the command to launch. Keys are lowercase exe names.
--
-- bash.exe is deliberately absent: tasklist reports the image name only, and
-- both Git Bash and the WSL launcher are called bash.exe, with bare `bash`
-- resolving to C:\Windows\system32\bash.exe (WSL) on this machine. Guessing
-- would silently open the wrong shell, so a bash parent falls through to the
-- pwsh default below. Running nvim inside WSL is unaffected — that is Linux
-- nvim, which takes the $SHELL branch above.
local WINDOWS_SHELLS = {
    ["pwsh.exe"] = "pwsh -NoLogo",
    ["powershell.exe"] = "powershell -NoLogo",
    ["cmd.exe"] = "cmd.exe",
    ["nu.exe"] = "nu",
}

local function parent_image_name()
    local ok, ppid = pcall(vim.uv.os_getppid)
    if not ok or not ppid then return nil end
    local ok2, res = pcall(function()
        return vim.system({ "tasklist", "/FI", "PID eq " .. ppid, "/NH", "/FO", "CSV" }, { text = true }):wait(3000)
    end)
    if not ok2 or not res or res.code ~= 0 or not res.stdout then return nil end
    -- CSV row looks like: "pwsh.exe","12345","Console","1","98,765 K"
    return res.stdout:match('^%s*"([^"]+)"')
end

local function terminal_shell()
    if resolved_shell then return resolved_shell end

    if vim.fn.has("win32") == 0 then
        resolved_shell = (vim.env.SHELL ~= "" and vim.env.SHELL) or vim.o.shell
        return resolved_shell
    end

    local parent = parent_image_name()
    local mapped = parent and WINDOWS_SHELLS[parent:lower()]
    if mapped and vim.fn.executable(mapped:match("^%S+")) == 1 then
        resolved_shell = mapped
        return resolved_shell
    end

    -- Launched from wezterm-gui directly, Explorer, a shortcut, a task runner:
    -- no shell parent to inherit, so prefer pwsh over nvim's cmd.exe default.
    if vim.fn.executable("pwsh") == 1 then
        resolved_shell = "pwsh -NoLogo"
        return resolved_shell
    end

    resolved_shell = vim.o.shell
    return resolved_shell
end

require("toggleterm").setup({
    direction = "horizontal",
    size = 15,
    close_on_exit = true,
    shell = terminal_shell,
})

-- Bind both keycodes — most terminals send Ctrl+/ as <C-_> (ASCII control byte),
-- while WezTerm/kitty/foot send the literal <C-/>. Mapping both covers all cases.
for _, key in ipairs({ "<C-/>", "<C-_>" }) do
    vim.keymap.set({ "n", "t" }, key, "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
end

