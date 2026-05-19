-- Project-wide find &amp; replace UI. Edit replacements in-buffer, then :w to apply.
require("grug-far").setup({})

vim.keymap.set("n", "<leader>sR", function() require("grug-far").open() end,
    { desc = "Project find &amp; replace" })
vim.keymap.set("v", "<leader>sR", function()
    require("grug-far").with_visual_selection()
end, { desc = "Replace selection (project)" })

require("which-key").add({ { "<leader>s", group = "Search/Replace", icon = { icon = "󰍉", color = "yellow" } } })
