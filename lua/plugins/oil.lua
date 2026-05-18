require("oil").setup({
    default_file_explorer = true,
    view_options = { show_hidden = true },
    float = { border = "rounded" },
    keymaps = {
        ["q"] = { "actions.close", mode = "n" },
    }
})

vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })

vim.keymap.set("n", "<leader>e", "<cmd>Oil --float<cr>", { desc = "Open file explorer" })

-- vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "Open file explorer" })
