-- nvim-treesitter `main` branch (required on Neovim 0.12 — `master` parsers
-- use the old TSNode API and crash with: attempt to call method 'range').
-- New API: explicit install + per-filetype highlight start.
local parsers = require("util.treesitter-parsers")

local ok, ts = pcall(require, "nvim-treesitter")
if ok and type(ts.install) == "function" then
    -- Block until any missing parser is built. Without :wait(), install is
    -- async and the first file load can race the .so creation, leaving the
    -- buffer (and fff previews) unhighlighted.
    local handle = ts.install(parsers)
    if handle and handle.wait then pcall(function() handle:wait(60000) end) end
else
    vim.notify(
        "nvim-treesitter `main` branch not loaded — run :lua vim.pack.update() or wipe ~/.local/share/nvim/site/pack/core/opt/nvim-treesitter",
        vim.log.levels.WARN
    )
end

-- Start treesitter highlighting for any filetype that has a parser available.
-- Using "*" instead of a hardcoded list so picker/preview buffers (fff, telescope)
-- also get highlighted, not just files opened by name.
-- fff preview buffers load content but don't run filetype detection. Force it
-- so our FileType autocmd below can start treesitter on them.
vim.api.nvim_create_autocmd({ "BufWinEnter", "BufRead" }, {
    pattern = "*",
    callback = function(ev)
        if vim.bo[ev.buf].filetype ~= "" then return end
        local name = vim.api.nvim_buf_get_name(ev.buf)
        if name == "" then return end
        local ft = vim.filetype.match({ filename = name, buf = ev.buf })
        if ft then vim.bo[ev.buf].filetype = ft end
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "*",
    callback = function(ev)
        local ft = vim.bo[ev.buf].filetype
        if ft == "" then return end
        local lang = vim.treesitter.language.get_lang(ft) or ft
        if pcall(vim.treesitter.language.add, lang) then
            pcall(vim.treesitter.start, ev.buf, lang)
            pcall(function()
                vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end)
        end
    end,
})
