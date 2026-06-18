-- Ctrl+h/j/k/l moves between nvim splits.
-- Plugin's own mappings are disabled via `g:tmux_navigator_no_mappings`
-- in config/options.lua — we re-define only the normal-mode ones here so
-- terminal-mode keystrokes reach Claude/omp/shell unmodified.
-- If nvim is running inside tmux, the same keys cross into adjacent tmux panes
-- (provided the matching snippet is in your ~/.tmux.conf — see the plugin README).
vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  { desc = "Window/pane left"  })
vim.keymap.set("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>",  { desc = "Window/pane down"  })
vim.keymap.set("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>",    { desc = "Window/pane up"    })
vim.keymap.set("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", { desc = "Window/pane right" })

-- Terminal-mode nav. Use the classic <C-\\><C-N>:cmd<CR> form (not <cmd>),
-- which explicitly exits terminal mode first — Claude/omp treat <cmd>
-- as raw text and would leak it into the prompt.
vim.keymap.set("t", "<C-h>", [[<C-\><C-n>:TmuxNavigateLeft<CR>]],  { desc = "Window/pane left"  })
vim.keymap.set("t", "<C-j>", [[<C-\><C-n>:TmuxNavigateDown<CR>]],  { desc = "Window/pane down"  })
vim.keymap.set("t", "<C-k>", [[<C-\><C-n>:TmuxNavigateUp<CR>]],    { desc = "Window/pane up"    })
vim.keymap.set("t", "<C-l>", [[<C-\><C-n>:TmuxNavigateRight<CR>]], { desc = "Window/pane right" })

-- Terminal-mode nav: the global <C-h/j/k/l> t-maps above navigate out of ANY
-- terminal. AI/chat terminals (claudecode, omp) must instead keep raw
-- Ctrl+h/j/k/l so the inner app receives them — so for those buffers we shadow
-- the global maps buffer-locally with a literal passthrough. Plain shells keep
-- the global nav maps. To leave an AI buffer: <C-\><C-n> then Ctrl+h.
-- NB: TermOpen (not FileType=toggleterm) — claudecode's terminal has no
-- toggleterm filetype, so a FileType autocmd never fired for it.
vim.api.nvim_create_autocmd("TermOpen", {
    callback = function(ev)
        vim.defer_fn(function()
            if not vim.api.nvim_buf_is_valid(ev.buf) then return end
            local name = vim.api.nvim_buf_get_name(ev.buf) or ""
            local cmd  = vim.b[ev.buf].terminal_job_cmd or ""
            local is_ai = (name .. " " .. cmd):lower():match("claude")
                or (name .. " " .. cmd):lower():match("omp")
            if not is_ai then return end -- plain shell: the global nav maps are correct
            -- AI panel: shadow the global nav maps so Ctrl+h/j/k/l reach the inner app.
            local opts = { buffer = ev.buf, silent = true }
            for _, k in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
                vim.keymap.set("t", k, k, opts) -- literal passthrough to the terminal job
            end
        end, 50)
    end,
})
