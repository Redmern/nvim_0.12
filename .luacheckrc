-- luacheck config for this nvim config.
std = "lua54+luajit"
globals = { "vim" }
ignore = {
    "212", -- unused argument
    "631", -- line is too long (we let stylua handle wrapping)
}
exclude_files = {
    "lua/util/*.lua",
}
