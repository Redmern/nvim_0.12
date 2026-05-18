local ai = require("mini.ai")

ai.setup({
    custom_textobjects = {
        -- "g" = entire buffer (vag / yag / dag / cag)
        g = function()
            return {
                from = { line = 1, col = 1 },
                to   = { line = vim.fn.line("$"), col = math.max(vim.fn.getline("$"):len(), 1) },
            }
        end,
    },
})
