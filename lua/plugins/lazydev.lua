-- Neovim Lua API intellisense for lua_ls.
-- Adds the Neovim runtime + your plugin sources to lua_ls's workspace library
-- on demand, so `vim.*` and plugin APIs get completion/hover without warnings.
require("lazydev").setup({
    library = {
        -- Load luv (vim.uv) type definitions when vim.uv is referenced
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
})
