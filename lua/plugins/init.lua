-- Plugin dispatcher. Specs in lua/plugins/specs.lua, configs alongside.
-- Order matters where one plugin's config relies on another being set up
-- (e.g. lsp before roslyn-config, blink before LSP-attach, etc.).
vim.pack.add(require("plugins.specs"))

-- VSCode (vscode-neovim) owns UI, LSP, tabs, statusline, terminal, file tree
-- already -- loading our full UI/LSP/DAP plugin stack on top of its embedded
-- headless nvim fights it and breaks basic editing (mode switches, keys).
-- Only load pure editing-behavior plugins there.
local vscode_modules = {
    "treesitter",
    "treesitter-textobjects",
    "flash",
    "mini",
}

local full_modules = {
    "catppuccin",
    "monokai-pro",
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
    -- "harpoon", -- benched, see specs.lua
    "bufferline",
    "lualine",
    "modicator",
    "lazygit",
    "gitsigns",
    "diffview",
    "grug-far",
    "trouble",
    "persistence",
    "conform",
    "flash",
    "hlslens",
    "treesj",
    "tabout", -- after blink: blink's <Tab> "fallback" step hands off to tabout's global map
    "tiny-inline-diagnostic",
    "tiny-code-action",
    "indent-blankline",
    "colorizer",
    "render-markdown",
    "live-preview",
    "img-clip",
    "autolist",
    "window-picker",
    "noice",
    "mini",
    "claudecode",
    "omp",
    "smart-splits",
    "toggleterm",
    "typr",
}

local modules = vim.g.vscode and vscode_modules or full_modules

for _, name in ipairs(modules) do
    local ok, err = pcall(require, "plugins." .. name)
    if not ok then
        vim.schedule(function()
            vim.notify(("plugins.%s failed: %s"):format(name, err), vim.log.levels.ERROR)
        end)
    end
end
