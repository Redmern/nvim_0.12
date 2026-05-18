require("bufferline").setup({
    options = {
        diagnostics = "nvim_lsp",
        show_buffer_close_icons = false,
        show_close_icon = false,
        -- Hide terminal buffers (Claude Code, opencode, :terminal) from the bufferline
        custom_filter = function(buf_number)
            return vim.bo[buf_number].buftype ~= "terminal"
        end,
    },
})

-- Shift-L / Shift-H to switch tabs
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })

vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>ba", "<cmd>%bdelete<cr>", { desc = "Close all buffers" })
vim.keymap.set("n", "<leader>be", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
