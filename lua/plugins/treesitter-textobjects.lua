-- Treesitter textobjects (main branch). Adds:
--   daf / dif       — function (around / inside)
--   dac / dic       — class
--   ]m / [m         — next / prev function start
--   ]M / [M         — next / prev function end
local select = require("nvim-treesitter-textobjects.select")
local move   = require("nvim-treesitter-textobjects.move")

local function map(mode, lhs, fn, desc)
    vim.keymap.set(mode, lhs, fn, { silent = true, desc = desc })
end

-- Selection
for _, m in ipairs({ "x", "o" }) do
    map(m, "af", function() select.select_textobject("@function.outer", "textobjects") end, "around function")
    map(m, "if", function() select.select_textobject("@function.inner", "textobjects") end, "inside function")
    map(m, "ac", function() select.select_textobject("@class.outer",    "textobjects") end, "around class")
    map(m, "ic", function() select.select_textobject("@class.inner",    "textobjects") end, "inside class")
    map(m, "aa", function() select.select_textobject("@parameter.outer", "textobjects") end, "around arg")
    map(m, "ia", function() select.select_textobject("@parameter.inner", "textobjects") end, "inside arg")
end

-- Movement
map({ "n", "x", "o" }, "]m", function() move.goto_next_start("@function.outer", "textobjects") end, "next function")
map({ "n", "x", "o" }, "[m", function() move.goto_previous_start("@function.outer", "textobjects") end, "prev function")
map({ "n", "x", "o" }, "]M", function() move.goto_next_end("@function.outer",   "textobjects") end, "next function end")
map({ "n", "x", "o" }, "[M", function() move.goto_previous_end("@function.outer", "textobjects") end, "prev function end")
