-- Defaults give: selected = full Normal color, inactive = greyed/dimmed.
-- Matches LazyVim's bufferline behaviour (no custom highlights).
local opts = {
    options = {
        diagnostics = "nvim_lsp",
        diagnostics_update_in_insert = false, -- silences the bufferline 4.6.3 deprecation warning
        always_show_bufferline = false,
        show_buffer_close_icons = true,
        show_close_icon = false,
        color_icons = true,
        offsets = {
            { filetype = "neo-tree", text = "Neo-tree", highlight = "Directory", text_align = "left" },
        },
        -- Hide terminal buffers (Claude Code, opencode, :terminal) from the bufferline
        custom_filter = function(buf_number)
            return vim.bo[buf_number].buftype ~= "terminal"
        end,
    },
}

require("bufferline").setup(opts)

-- Omarchy theme sync (config/autocmds.lua) re-runs :colorscheme on FocusGained.
-- Bufferline caches its derived hl groups at setup() time → they go stale and
-- everything turns grey. Re-init on every ColorScheme to refresh.
vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function() require("bufferline").setup(opts) end,
})

-- Shift-L / Shift-H to switch tabs
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })

-- Layout-preserving buffer delete: switch the window to another listed buffer
-- (or a scratch buf if none) before wiping the target. Without this, closing
-- the last code buffer collapses the central window and the side panels
-- (neo-tree, Claude) grow to fill the empty space.
local function close_buffer_keep_layout()
    local bufnr = vim.api.nvim_get_current_buf()

    local alt = vim.fn.bufnr("#")
    if alt < 1 or alt == bufnr or not vim.api.nvim_buf_is_valid(alt)
       or not vim.bo[alt].buflisted then
        alt = -1
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if b ~= bufnr and vim.bo[b].buflisted and vim.bo[b].buftype == "" then
                alt = b; break
            end
        end
    end

    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
        vim.api.nvim_win_call(win, function()
            if alt > 0 then
                vim.api.nvim_win_set_buf(win, alt)
            else
                vim.cmd("enew") -- fresh empty buffer keeps the window alive
            end
        end)
    end
    pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
end

vim.keymap.set("n", "<leader>bd", close_buffer_keep_layout, { desc = "Close tab (keep layout)" })

-- Hook :bd / :bdelete / :BD into the same layout-preserving function. The
-- cabbrev only fires when bd/bdelete is the FIRST token, so things like
-- `:silent! bd` from plugins are unaffected.
vim.api.nvim_create_user_command("BD", close_buffer_keep_layout, { desc = "Close buffer (keep layout)" })
vim.cmd([[
    cnoreabbrev <expr> bd      (getcmdtype() == ':' && getcmdline() ==# 'bd')      ? 'BD' : 'bd'
    cnoreabbrev <expr> bdelete (getcmdtype() == ':' && getcmdline() ==# 'bdelete') ? 'BD' : 'bdelete'
]])
vim.keymap.set("n", "<leader>ba", "<cmd>%bdelete<cr>", { desc = "Close all buffers" })
vim.keymap.set("n", "<leader>be", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
