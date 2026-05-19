local function theme_for_bg()
    local cs = vim.g.colors_name or ""
    if cs:match("^catppuccin") then
        return (vim.o.background == "light") and "catppuccin-latte" or "catppuccin-mocha"
    end
    return "auto" -- lualine picks a matching theme from the current colorscheme
end

local function apply()
    require("lualine").setup({
        options = {
            theme = theme_for_bg(),
            globalstatus = true,
            disabled_filetypes = { statusline = { "dashboard", "alpha" } },
        },
        sections = {
            lualine_a = { "mode" },
            lualine_b = { "branch" },
            lualine_c = {
                {
                    "diagnostics",
                    symbols = { error = " ", warn = " ", info = " ", hint = " " },
                },
                { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
                { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" } },
            },
            lualine_x = {
                {
                    "diff",
                    symbols = { added = " ", modified = " ", removed = " " },
                },
            },
            lualine_y = {
                { "progress", separator = " ", padding = { left = 1, right = 0 } },
                { "location", padding = { left = 0, right = 1 } },
            },
            lualine_z = {
                function() return " " .. os.date("%R") end,
            },
        },
        extensions = { "neo-tree", "lazy", "toggleterm", "oil" },
    })
end

apply()

-- Re-pick the lualine theme whenever the background flips
-- (sync_os_theme in config/autocmds.lua flips it on FocusGained).
vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "background",
    callback = apply,
})
