-- fff.nvim — fast file finder. Replaces telescope find_files on <leader><space>
-- and <leader>ff. First run will build the Rust binary (cargo required).
require("fff").setup({
  debug = {
    enabled = false,
    show_scores = false,
  },
})

local fff = function() return require("fff") end

vim.keymap.set("n", "<leader><space>", function() fff().find_files() end, { desc = "FFFind files" })
vim.keymap.set("n", "<leader>/", function() fff().live_grep() end, { desc = "LiFFFe grep" })
vim.keymap.set("n", "fz", function()
  fff().live_grep({ grep = { modes = { "fuzzy", "plain" } } })
end, { desc = "Live fffuzy grep" })
vim.keymap.set("n", "<leader>sw", function()
  fff().live_grep({ query = vim.fn.expand("<cword>") })
end, { desc = "Search current word" })

-- Bufferswitch picker (replaces telescope.builtin.buffers). Lists listed,
-- normal-buftype buffers and jumps to the chosen one.
vim.keymap.set("n", "<leader>fb", function()
    local items = {}
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buflisted and vim.bo[b].buftype == "" then
            local name = vim.api.nvim_buf_get_name(b)
            if name ~= "" then table.insert(items, { bufnr = b, name = vim.fn.fnamemodify(name, ":.") }) end
        end
    end
    vim.ui.select(items, {
        prompt  = "Buffer:",
        format_item = function(it) return it.name end,
    }, function(choice)
        if choice then vim.api.nvim_set_current_buf(choice.bufnr) end
    end)
end, { desc = "Switch buffer" })

-- Help-tag completion via cmdline (replaces telescope.builtin.help_tags) —
-- blink.cmp's cmdline source completes :help <Tab> well enough.
vim.keymap.set("n", "<leader>fh", ":help ", { desc = "Help tag" })

-- CRLF fix for the preview window. fff previews are scratch buffers filled via
-- nvim_buf_set_lines, so Neovim never runs 'fileformat' detection on them; a
-- CRLF file keeps its trailing \r on every line and renders as ^M
-- (fff/file_picker/preview.lua splits the raw bytes on "\n" only). fff's own
-- line setters are file-locals, so wrapping the API call is the only hook point.
local ok_ui, picker_ui = pcall(require, "fff.picker_ui")
if ok_ui then
    local set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(buf, start, stop, strict, lines)
        local state = picker_ui.state
        if state and buf == state.preview_buf and lines and #lines > 0 then
            local cleaned
            for i = 1, #lines do
                local line = lines[i]
                if type(line) == "string" and line:sub(-1) == "\r" then
                    cleaned = cleaned or vim.list_slice(lines, 1, #lines)
                    cleaned[i] = line:sub(1, -2)
                end
            end
            lines = cleaned or lines
        end
        return set_lines(buf, start, stop, strict, lines)
    end
end
