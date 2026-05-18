require("telescope").setup({})

local tb = require("telescope.builtin")
vim.keymap.set("n", "<leader><space>", tb.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>/", tb.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", tb.buffers, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fh", tb.help_tags, { desc = "Help tags" })
