-- In-buffer markdown rendering — headings, code blocks, tables get styled.
-- Auto-disables in insert mode and in raw view (`:RenderMarkdown toggle`).
require("render-markdown").setup({
    completions = { blink = { enabled = true } }, -- markdown link completions via blink
    file_types  = { "markdown", "Avante" },        -- claudecode buffers are not markdown
    heading     = { sign = false },                -- don't shove icons into sign column
})
