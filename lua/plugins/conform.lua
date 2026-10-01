require("conform").setup({
    formatters_by_ft = {
        cs   = { "csharpier" },
        lua  = { "stylua" },
        json = { "prettier" },
    },
    -- No format_on_save on purpose: `:w` writes the file and nothing else.
    -- Formatting is explicit, via <leader>lf below.
})

-- Format on demand. Normal mode = whole buffer, visual mode = selected range.
-- lsp_fallback lets a language server format when no CLI formatter is configured.
local function format()
    require("conform").format({ timeout_ms = 1000, lsp_fallback = true }, function(err)
        if err then
            vim.notify("conform: " .. err, vim.log.levels.WARN, { title = "format" })
        end
    end)
end

vim.keymap.set({ "n", "v" }, "<leader>lf", format, { desc = "Format" })
