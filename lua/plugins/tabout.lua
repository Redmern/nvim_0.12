-- Insert-mode <Tab> / <S-Tab> jump out of the enclosing quote/bracket pair.
--
-- <Tab> ownership: blink.cmp's "super-tab" preset binds <Tab> buffer-locally
-- on InsertEnter as { accept, snippet_forward, "fallback" }. "fallback" runs the
-- pre-existing global <Tab> mapping, which is the one tabout installs here. So
-- the chain is: completion menu open → accept; snippet active → next
-- placeholder; otherwise → tabout; nothing to tab out of → a normal tab.
-- `completion = false` because tabout's pumvisible() check is for the native
-- popup menu, which blink doesn't use.
require("tabout").setup({
    tabkey = "<Tab>",
    backwards_tabkey = "<S-Tab>",
    act_as_tab = true,
    act_as_shift_tab = false,
    enable_backwards = true,
    completion = false,
    tabouts = {
        { open = "'", close = "'" },
        { open = '"', close = '"' },
        { open = "`", close = "`" },
        { open = "(", close = ")" },
        { open = "[", close = "]" },
        { open = "{", close = "}" },
        { open = "<", close = ">" }, -- C# generics: List<string>
    },
    ignore_beginning = true,
    exclude = {},
})
