-- Split / join argument lists, tables, arrays, object literals via treesitter.
-- Default keymaps are off: they land on <leader>m/j/s, and <leader>m is the
-- Markdown group here, <leader>s is Search/Replace. <leader>j is free.
-- treesj ships no c_sharp preset (java.lua is the closest analogue), so one is
-- defined here. Node names verified against the tree-sitter-c-sharp parser.
local lang_utils = require("treesj.langs.utils")
local c_sharp = {
    argument_list = lang_utils.set_preset_for_args(), -- Foo(a, b, c)
    parameter_list = lang_utils.set_preset_for_args(), -- void M(int a, string b)
    initializer_expression = lang_utils.set_preset_for_dict(), -- new P { X = 1 } / new List<T> { 1, 2 }
    block = lang_utils.set_preset_for_statement(),
    method_declaration = { target_nodes = { "block" } },
    if_statement = { target_nodes = { "block" } },
    object_creation_expression = { target_nodes = { "initializer_expression" } },
    implicit_array_creation_expression = { target_nodes = { "initializer_expression" } },
}

require("treesj").setup({
    use_default_keymaps = false,
    max_join_length = 120,
    cursor_behavior = "hold",
    langs = { c_sharp = c_sharp },
})

vim.keymap.set("n", "<leader>j", require("treesj").toggle, { desc = "Split/join block" })
vim.keymap.set("n", "<leader>J", function()
    require("treesj").toggle({ split = { recursive = true } })
end, { desc = "Split/join block (recursive)" })
