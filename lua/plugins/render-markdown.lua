-- In-buffer markdown rendering — headings, code blocks, tables get styled.
-- Auto-disables in insert mode and in raw view (`:RenderMarkdown toggle`).
require("render-markdown").setup({
    completions = { blink = { enabled = true } }, -- markdown link completions via blink
    file_types  = { "markdown", "Avante" },        -- claudecode buffers are not markdown
    heading     = { sign = false },                -- don't shove icons into sign column
    -- keep rendering during visual modes (presenting: see autocmds.lua markdown
    -- dim/spotlight). Default is { n, c, t }, which un-renders on v/V/ctrl-v.
    render_modes = { "n", "c", "t", "v", "V", "\22" },
})
