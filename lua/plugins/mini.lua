-- mini.* — multiple modules from one repo. Replaces the per-module specs.
-- Note: bonus `mini.surround` added while consolidating (sa{motion}<char>,
--       sd<char>, sr<old><new>).
require("mini.ai").setup({
    custom_textobjects = {
        -- whole buffer: vag selects the entire document (also yag, dag, cag, ...)
        g = function()
            return {
                from = { line = 1, col = 1 },
                to = { line = vim.fn.line("$"), col = math.max(vim.fn.getline("$"):len(), 1) },
            }
        end,
    },
})

require("mini.files").setup({
    -- oil owns `nvim <dir>` / `-`; without this mini.files hijacks directory buffers
    options = { use_as_default_explorer = false },
})
vim.keymap.set("n", "<leader>fm", function()
    local minifiles = require("mini.files")
    if not minifiles.close() then
        -- non-file buffers (oil://, terminals, [No Name]) can't anchor the view
        local path = vim.api.nvim_buf_get_name(0)
        if vim.uv.fs_stat(path) == nil then path = vim.uv.cwd() end
        minifiles.open(path, false)
    end
end, { desc = "Mini.files (current file)" })

require("mini.pairs").setup({
    modes = { insert = true, command = false, terminal = false },
})

require("mini.comment").setup({
    options = {
        custom_commentstring = function() return vim.bo.commentstring end,
    },
})

require("mini.surround").setup({})
