-- LuaSnip — snippet engine. friendly-snippets provides the snippets in
-- VS Code JSON format; load_from_vscode picks them up. blink.cmp's `snippets`
-- source (wired in blink.lua) reads from LuaSnip.
local ls = require("luasnip")
ls.config.set_config({
    history = true,
    updateevents = "TextChanged,TextChangedI",
})

require("luasnip.loaders.from_vscode").lazy_load() -- friendly-snippets
