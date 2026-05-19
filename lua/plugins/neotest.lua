-- neotest + neotest-dotnet. Runs individual xUnit / nUnit / MSTest tests.
require("neotest").setup({
    adapters = {
        require("neotest-dotnet")({
            dap = { args = { justMyCode = false }, adapter_name = "coreclr" },
            discovery_root = "solution", -- treat the whole .sln/.slnx as one project
        }),
    },
    output = { open_on_run = true },
    quickfix = { enabled = false },
})

local nt = function() return require("neotest") end
vim.keymap.set("n", "<leader>tt", function() nt().run.run(vim.fn.expand("%")) end,  { desc = "Test file" })
vim.keymap.set("n", "<leader>tn", function() nt().run.run() end,                    { desc = "Test nearest" })
vim.keymap.set("n", "<leader>td", function() nt().run.run({ strategy = "dap" }) end, { desc = "Debug nearest test" })
vim.keymap.set("n", "<leader>ts", function() nt().summary.toggle() end,             { desc = "Test summary" })
vim.keymap.set("n", "<leader>to", function() nt().output.open({ enter = true }) end, { desc = "Test output" })
vim.keymap.set("n", "<leader>tS", function() nt().run.stop() end,                   { desc = "Stop test" })

require("which-key").add({ { "<leader>t", group = "Test", icon = { icon = "󰙨", color = "green" } } })
