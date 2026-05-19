require("conform").setup({
    formatters_by_ft = {
        cs   = { "csharpier" },
        lua  = { "stylua" },
        json = { "prettier" },
    },
    -- Surface format failures instead of silently skipping. Conform's
    -- format_on_save can be a function returning the args table; we use the
    -- callback form to get a post-format hook.
    format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
        return { timeout_ms = 1000, lsp_fallback = true }, function(err)
            if err then
                vim.notify("conform: " .. err, vim.log.levels.WARN, { title = "format on save" })
            end
        end
    end,
})

-- Per-buffer / global toggle (handy when a stylua run is fighting you)
vim.api.nvim_create_user_command("FormatDisable", function(args)
    if args.bang then vim.b.disable_autoformat = true else vim.g.disable_autoformat = true end
end, { bang = true, desc = "Disable format-on-save (! = buffer only)" })
vim.api.nvim_create_user_command("FormatEnable", function()
    vim.b.disable_autoformat = false
    vim.g.disable_autoformat = false
end, { desc = "Re-enable format-on-save" })

vim.keymap.set("n", "<leader>lf", function() require("conform").format() end, { desc = "Format" })
