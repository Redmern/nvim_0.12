-- nvim-dap + dap-ui — C# / Blazor focused
local dap = require("dap")
local dapui = require("dapui")

-- Sign-column symbols for breakpoints / current execution (replaces default "B")
vim.fn.sign_define("DapBreakpoint",          { text = "●", texthl = "DiagnosticError", linehl = "", numhl = "" })
vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn",  linehl = "", numhl = "" })
vim.fn.sign_define("DapLogPoint",            { text = "◆", texthl = "DiagnosticInfo",  linehl = "", numhl = "" })
vim.fn.sign_define("DapStopped",             { text = "▶", texthl = "DiagnosticOk",    linehl = "Visual", numhl = "" })
vim.fn.sign_define("DapBreakpointRejected",  { text = "○", texthl = "DiagnosticHint",  linehl = "", numhl = "" })

-- ---------------------------------------------------------------------------
-- Mason-managed binaries (netcoredbg for .NET, js-debug-adapter for Blazor WASM)
-- ---------------------------------------------------------------------------
require("mason-tool-installer").setup({
  ensure_installed = {
    -- Roslyn pinned: random upstream version bumps have a history of
    -- changing diagnostic output (IDE0005 surfacing, missing code-fixes,
    -- razor arg crashes). Bump deliberately, not on every `:MasonUpdate`.
    { "roslyn", version = "5.8.0-1.26262.10" },
    "netcoredbg",
    "js-debug-adapter",
    "csharpier",
    "stylua",
  },
  run_on_start = true,
  auto_update = false,
})

-- ---------------------------------------------------------------------------
-- C# adapter (netcoredbg) defined directly. dap-cs is deliberately NOT used —
-- it overwrites dap.configurations.cs and conflicts with our attach flow
-- (matches old ~/.config/nvim setup that works).
-- ---------------------------------------------------------------------------
local netcoredbg = {
  type = "executable",
  -- Resolve at debug time, not require time — mason may install it after this
  -- file loads, so a value captured here could be an empty string.
  command = function() return vim.fn.exepath("netcoredbg") end,
  args = { "--interpreter=vscode" },
}
dap.adapters.coreclr    = netcoredbg
dap.adapters.netcoredbg = netcoredbg
vim.opt.switchbuf:append("useopen")

dap.configurations.cs = {
  {
    type = "coreclr",
    name = "Launch (select DLL)",
    request = "launch",
    console = "integratedTerminal",
    program = function()
      return vim.fn.input("Path to DLL: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
    end,
    stopAtEntry = false,
  },
  {
    type = "coreclr",
    name = "Attach",
    request = "attach",
    processId = require("dap.utils").pick_process,
  },
}

-- Launch terminal opens as a bottom split (15 rows)
dap.defaults.fallback.terminal_win_cmd = "belowright 15new"

-- ---------------------------------------------------------------------------
-- pwa-chrome adapter for Blazor WebAssembly (debug C# running in the browser)
-- ---------------------------------------------------------------------------
local mason_path = vim.fn.stdpath("data") .. "/mason"
dap.adapters["pwa-chrome"] = {
  type = "server",
  host = "localhost",
  port = "${port}",
  executable = {
    command = "node",
    args = {
      mason_path .. "/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
      "${port}",
    },
  },
}

-- Extra launch config for Blazor WASM (dap-cs already provided the standard C# one).
-- Run the Blazor project in a terminal first, then attach with this.
dap.configurations.cs = dap.configurations.cs or {}
table.insert(dap.configurations.cs, {
  type = "pwa-chrome",
  name = "Blazor WASM (Chrome attach @ :9222)",
  request = "attach",
  port = 9222,
  webRoot = "${workspaceFolder}/wwwroot",
  sourceMapPathOverrides = {
    ["dotnet://*.dll/*"] = "${workspaceFolder}/*",
  },
})

-- ---------------------------------------------------------------------------
-- dap-ui layout: side panel (right) + bottom REPL/console
-- ---------------------------------------------------------------------------
dapui.setup({
  floating = { border = "rounded" },
  layouts = {
    {
      position = "right",
      size = 40,
      elements = {
        { id = "scopes",      size = 0.30 },
        { id = "watches",     size = 0.25 },
        { id = "stacks",      size = 0.25 },
        { id = "breakpoints", size = 0.20 },
      },
    },
    {
      position = "bottom",
      size = 10,
      elements = {
        { id = "repl",    size = 0.5 },
        { id = "console", size = 0.5 },
      },
    },
  },
})

-- No auto dap-ui open on session start. Use <leader>du to toggle when needed.


-- ---------------------------------------------------------------------------
-- Keymaps
-- ---------------------------------------------------------------------------
local map = function(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { desc = desc }) end

-- Standard function-key shortcuts (match VS Code muscle memory)
map("<F5>",  dap.continue,          "Continue / Start debug")
map("<F8>",  dap.step_out,          "Step out")
map("<F9>",  dap.toggle_breakpoint, "Toggle breakpoint")
map("<F10>", dap.step_over,         "Step over")
map("<F11>", dap.step_into,         "Step into")

-- <leader>d* group — generic DAP
map("<leader>db", dap.toggle_breakpoint, "Toggle breakpoint")
map("<leader>dc", dap.continue,          "Continue / Start")
map("<leader>di", dap.step_into,         "Step into")
map("<leader>do", dap.step_over,         "Step over")
map("<leader>dO", dap.step_out,          "Step out")
map("<leader>du", dapui.toggle,          "Toggle DAP UI")
map("<leader>dr", dap.repl.toggle,       "Toggle REPL")
map("<leader>dl", dap.run_last,          "Run last")

-- Peek value: K-like hover popup. <leader>de = peek (closes on cursor move),
-- <leader>dw = peek and stay (enter the float to scroll/inspect children).
vim.keymap.set({ "n", "v" }, "<leader>de", function() require("dapui").eval() end,
    { desc = "DAP Eval (peek)" })
vim.keymap.set({ "n", "v" }, "<leader>dw", function() require("dapui").eval(nil, { enter = true }) end,
    { desc = "DAP Eval (peek + focus)" })

-- <leader>dA — Auto-Debug: resolve (builtin/vscode/cache) or discover a debug
-- config with Claude, gated by a confirm surfacing the literal command.
map("<leader>dA", function() require("util.autodebug").auto_debug() end,
    "Auto-Debug (resolve or discover config)")

-- <leader>d* — .NET workflow (matches old config exactly)
local dotnet = function() return require("util.dotnet-debug") end
map("<leader>dd", function() dotnet().debug_with_terminal() end, "Debug .NET (build + run + auto-attach)")
map("<leader>dR", function() dotnet().run_in_terminal() end,     "Run .NET (no attach)")
map("<leader>da", function() dotnet().attach_to_dotnet() end,    "Attach to .NET process")
map("<leader>dT", function() dotnet().toggle_terminal() end,     "Toggle .NET terminal")
map("<leader>dS", function() dotnet().stop_terminal() end,       "Stop .NET terminal")

-- <leader>G* — Godot workflow (build + run godot-mono, optional debugger attach)
local godot = function() return require("util.godot-debug") end
map("<leader>Gr", function() godot().run_game() end,       "Run Godot game (build + launch)")
map("<leader>Gd", function() godot().debug_game() end,     "Debug Godot (build + run + auto-attach)")
map("<leader>Ga", function() godot().attach_to_godot() end, "Attach to running Godot")
map("<leader>Ge", function() godot().open_editor() end,    "Open Godot editor")
map("<leader>Gb", function() godot().build() end,          "Build (dotnet build)")
map("<leader>Gi", function() godot().import_assets() end,  "Re-import assets (--headless --import)")
map("<leader>GT", function() godot().toggle_terminal() end, "Toggle Godot terminal")
map("<leader>GS", function() godot().stop() end,           "Stop Godot")

-- which-key icon under the existing <leader>d "Debug" group (no new group)
pcall(function()
  require("which-key").add({
    { "<leader>dA", icon = { icon = "󰚥", color = "cyan" } },
  })
end)
