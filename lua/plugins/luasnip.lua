-- LuaSnip — snippet engine. friendly-snippets provides the snippets in
-- VS Code JSON format; load_from_vscode picks them up. blink.cmp's `snippets`
-- source (wired in blink.lua) reads from LuaSnip.
local ls = require("luasnip")
ls.config.set_config({
    history = true,
    updateevents = "TextChanged,TextChangedI",
})

require("luasnip.loaders.from_vscode").lazy_load() -- friendly-snippets

-- GitHub / Obsidian callout blocks. Type `note`, `tip`, `warning`, `important`
-- or `caution` in a markdown buffer and expand.
local s, t, i = ls.snippet, ls.text_node, ls.insert_node
ls.add_snippets(
    "markdown",
    vim.tbl_map(function(kind)
        return s(kind:lower(), { t({ "> [!" .. kind .. "]", "> " }), i(0) })
    end, { "NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION" })
)
