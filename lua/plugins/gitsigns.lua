-- Inline git: gutter signs, hunk preview/stage/reset, blame-line.
require("gitsigns").setup({
    signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
        untracked    = { text = "▎" },
    },
    current_line_blame = false, -- toggle with <leader>gb
    on_attach = function(bufnr)
        local gs = require("gitsigns")
        local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
        map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")
        map("n", "<leader>gh", gs.preview_hunk,                    "Preview hunk")
        map("n", "<leader>gs", gs.stage_hunk,                      "Stage hunk")
        map("n", "<leader>gr", gs.reset_hunk,                      "Reset hunk")
        map("n", "<leader>gb", function() gs.toggle_current_line_blame() end, "Toggle line blame")
        map("n", "<leader>gd", gs.diffthis,                        "Diff against index")
        map("v", "<leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage selection")
        map("v", "<leader>gr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset selection")
    end,
})
