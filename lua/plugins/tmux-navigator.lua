-- Ctrl+h/j/k/l moves between nvim splits.
-- Plugin's own mappings are disabled via `g:tmux_navigator_no_mappings`
-- in config/options.lua — we re-define only the normal-mode ones here so
-- terminal-mode keystrokes reach Claude/opencode/shell unmodified.
-- If nvim is running inside tmux, the same keys cross into adjacent tmux panes
-- (provided the matching snippet is in your ~/.tmux.conf — see the plugin README).
vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  { desc = "Window/pane left"  })
vim.keymap.set("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>",  { desc = "Window/pane down"  })
vim.keymap.set("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>",    { desc = "Window/pane up"    })
vim.keymap.set("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", { desc = "Window/pane right" })

-- Terminal-mode nav. Use the classic <C-\\><C-N>:cmd<CR> form (not <cmd>),
-- which explicitly exits terminal mode first — Claude/opencode treat <cmd>
-- as raw text and would leak it into the prompt.
vim.keymap.set("t", "<C-h>", [[<C-\><C-n>:TmuxNavigateLeft<CR>]],  { desc = "Window/pane left"  })
vim.keymap.set("t", "<C-j>", [[<C-\><C-n>:TmuxNavigateDown<CR>]],  { desc = "Window/pane down"  })
vim.keymap.set("t", "<C-k>", [[<C-\><C-n>:TmuxNavigateUp<CR>]],    { desc = "Window/pane up"    })
vim.keymap.set("t", "<C-l>", [[<C-\><C-n>:TmuxNavigateRight<CR>]], { desc = "Window/pane right" })

-- Terminal-mode nav: opt-in only for plain toggleterm shells. AI/chat
-- terminals (claudecode, opencode) keep raw Ctrl+h/j/k/l so the inner app
-- receives them. To leave those buffers: <C-\><C-n> then Ctrl+h/etc.
vim.api.nvim_create_autocmd("FileType", {
    pattern = "toggleterm",
    callback = function(ev)
        -- claudecode/opencode run inside toggleterm too — skip them so
        -- Ctrl+h/j/k/l pass through to the inner app.
        vim.defer_fn(function()
            if not vim.api.nvim_buf_is_valid(ev.buf) then return end
            local name = vim.api.nvim_buf_get_name(ev.buf) or ""
            local cmd  = vim.b[ev.buf].terminal_job_cmd or ""
            if (name .. " " .. cmd):lower():match("claude")
                or (name .. " " .. cmd):lower():match("opencode") then
                return
            end
            local opts = { buffer = ev.buf, silent = true }
            vim.keymap.set("t", "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  opts)
            vim.keymap.set("t", "<C-j>", "<cmd>TmuxNavigateDown<cr>",  opts)
            vim.keymap.set("t", "<C-k>", "<cmd>TmuxNavigateUp<cr>",    opts)
            vim.keymap.set("t", "<C-l>", "<cmd>TmuxNavigateRight<cr>", opts)
        end, 50)
    end,
})
