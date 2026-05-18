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
    "roslyn",            -- C# language server (used by lua/plugins/roslyn.lua)
    "netcoredbg",        -- .NET / Blazor Server debugger
    "js-debug-adapter",  -- Browser-side debugger for Blazor WASM via Chrome
    "csharpier",         -- already used by conform.nvim
    "stylua",            -- already used by conform.nvim
  },
  run_on_start = true,
  auto_update = false,
})

-- ---------------------------------------------------------------------------
-- C# adapter + base launch config via dap-cs (auto-finds the DLL from the csproj)
-- ---------------------------------------------------------------------------
require("dap-cs").setup({
  netcoredbg = {
    path = vim.fn.exepath("netcoredbg"),
  },
})

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

dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
dap.listeners.before.event_exited["dapui"]    = function() dapui.close() end

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

-- <leader>d* — .NET workflow (matches old config exactly)
local dotnet = function() return require("util.dotnet-debug") end
map("<leader>dd", function() dotnet().debug_with_terminal() end, "Debug .NET (build + run + auto-attach)")
map("<leader>dR", function() dotnet().run_in_terminal() end,     "Run .NET (no attach)")
map("<leader>da", function() dotnet().attach_to_dotnet() end,    "Attach to .NET process")
map("<leader>dT", function() dotnet().toggle_terminal() end,     "Toggle .NET terminal")
map("<leader>dS", function() dotnet().stop_terminal() end,       "Stop .NET terminal")
