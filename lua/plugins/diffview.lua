-- Branch-scale diff review: file panel on the left, diff on the right.
-- gitsigns covers a single file and its hunks; this covers "everything that
-- changed on this branch", which is the view you want after pushing.
require("diffview").setup({
    enhanced_diff_hl = true,
    view = {
        -- diff3_mixed shows the common ancestor, matching the zdiff3
        -- merge.conflictstyle set in ~/.config/git/config.
        merge_tool = { layout = "diff3_mixed", disable_diagnostics = true },
    },
    keymaps = {
        view = { { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } } },
        file_panel = { { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } } },
        file_history_panel = { { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } } },
    },
})

-- Three-dot: what this branch added since it forked, ignoring commits the base
-- picked up meanwhile. --imply-local makes the right-hand side the real working
-- file, so fixes can be typed straight into the review.
local function branch_diff()
    local base, ahead = require("util.git-base").nearest()
    if not base then
        vim.notify("diffview: no base branch found to diff against", vim.log.levels.WARN)
        return
    end
    -- Say which base was chosen -- a silently wrong base is the failure mode here.
    vim.notify(("diffview: %s...HEAD (%d commits)"):format(base, ahead), vim.log.levels.INFO)
    vim.cmd(("DiffviewOpen %s...HEAD --imply-local"):format(base))
end

vim.api.nvim_create_user_command("DiffviewBranch", branch_diff, { desc = "Diffview: branch vs nearest base" })

vim.keymap.set("n", "<leader>gv", "<cmd>DiffviewOpen<cr>", { desc = "Diffview: working tree" })
vim.keymap.set("n", "<leader>gV", branch_diff, { desc = "Diffview: branch vs base" })
vim.keymap.set("n", "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", { desc = "Diffview: this file's history" })
vim.keymap.set("n", "<leader>gF", "<cmd>DiffviewFileHistory<cr>", { desc = "Diffview: repo history" })
