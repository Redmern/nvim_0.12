local function theme_for_bg()
    local cs = vim.g.colors_name or ""
    if cs:match("^catppuccin") then
        return (vim.o.background == "light") and "catppuccin-latte" or "catppuccin-mocha"
    end
    return "auto" -- lualine picks a matching theme from the current colorscheme
end

local function apply()
    require("lualine").setup({
        options = { theme = theme_for_bg(), globalstatus = true },
    })
end

apply()

-- Re-pick the lualine theme whenever the background flips
-- (sync_os_theme in config/autocmds.lua flips it on FocusGained).
vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "background",
    callback = apply,
})
