require("which-key").setup({
    preset = "helix",
    win = {
        border = "rounded",
        padding = { 1, 1 },
    }
})

require("which-key").add({
    { "<leader>f", group = "Find" },
    { "<leader>g", group = "Git" },
    { "<leader>l", group = "LSP" },
    { "<leader>d", group = "Debug" },
    { "<leader>b", group = "Buffer" },
    { "<leader>c", group = "Claude Code" },
    { "<leader>o", group = "opencode",   mode = { "n", "x", "t" } },
})
