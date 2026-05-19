-- Plugin dispatcher. Specs in lua/plugins/specs.lua, configs alongside.
-- Order matters where one plugin's config relies on another being set up
-- (e.g. lsp before roslyn-config, blink before LSP-attach, etc.).
vim.pack.add(require("plugins.specs"))

local modules = {
    "catppuccin",
    "devicons",
    "oil",
    "neo-tree",
    "which-key",
    "treesitter",
    "treesitter-textobjects",
    "luasnip",        -- before blink so the snippet engine is loaded when blink reads it
    "blink",          -- before lsp.lua so capabilities exist when servers attach
    "lsp",
    "lazydev",
    "dap",
    "dap-virtual-text",
    "neotest",
    "supermaven",
    "fff",
    "harpoon",
    "bufferline",
    "lualine",
    "lazygit",
    "gitsigns",
    "grug-far",
    "trouble",
    "persistence",
    "conform",
    "flash",
    "tiny-inline-diagnostic",
    "indent-blankline",
    "colorizer",
    "render-markdown",
    "window-picker",
    "noice",
    "mini",
    "claudecode",
    "opencode",
    "tmux-navigator",
    "toggleterm",
}

for _, name in ipairs(modules) do
    local ok, err = pcall(require, "plugins." .. name)
    if not ok then
        vim.schedule(function()
            vim.notify(("plugins.%s failed: %s"):format(name, err), vim.log.levels.ERROR)
        end)
    end
end
