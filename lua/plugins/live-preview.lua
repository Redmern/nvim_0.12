-- Browser live-preview for Markdown / HTML / AsciiDoc / SVG. Pure Lua backend
-- (no Node/Deno/Python) — the server is Neovim's own event loop. KaTeX +
-- Mermaid + synced scrolling come for free.
--
-- <leader>mp toggles the preview for the current file; the server is process-
-- wide, so a second file just needs `:LivePreview start` (or <leader>mP).
require("livepreview.config").set({
    port = 5500,
    browser = "default", -- $BROWSER / xdg-open
    -- root = cwd (not the file's own dir): links between .md files resolve and
    -- the browser navigates to the linked file rendered as HTML, as long as
    -- both sit under the dir nvim was launched from. Launch nvim at the vault
    -- root for a set of interlinked notes.
    dynamic_root = false,
    sync_scroll = true,
    picker = "", -- auto-detect; falls back to vim.ui.select
})

local running = false

local function toggle()
    if running then
        vim.cmd("LivePreview close")
        running = false
        vim.notify("Live preview stopped", vim.log.levels.INFO)
    else
        vim.cmd("LivePreview start")
        running = true
        vim.notify("Live preview → http://localhost:5500", vim.log.levels.INFO)
    end
end

vim.keymap.set("n", "<leader>mp", toggle, { desc = "Markdown: toggle browser preview" })
vim.keymap.set("n", "<leader>mP", function()
    vim.cmd("LivePreview pick")
    running = true
end, { desc = "Markdown: preview a picked file" })
