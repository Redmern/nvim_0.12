-- mini.* — multiple modules from one repo. Replaces the per-module specs.
-- Note: bonus `mini.surround` added while consolidating (sa{motion}<char>,
--       sd<char>, sr<old><new>).
require("mini.ai").setup({})

require("mini.pairs").setup({
    modes = { insert = true, command = false, terminal = false },
})

require("mini.comment").setup({
    options = {
        custom_commentstring = function() return vim.bo.commentstring end,
    },
})

require("mini.surround").setup({})
