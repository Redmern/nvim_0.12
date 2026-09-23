-- Typing practice. typr's setup() reads (or creates) its stats file on disk,
-- so it's deferred until the first :Typr / :TyprStats instead of running at
-- startup. Its plugin/typr.lua defines both commands without calling setup;
-- they're redefined here after startup so the first call runs it.
local did_setup = false
local function ensure_setup()
    if not did_setup then
        require("typr").setup({})
        did_setup = true
    end
end

local function open()
    ensure_setup()
    require("typr").open()
end

local function stats()
    ensure_setup()
    require("typr.stats").open()
end

-- plugin/ scripts are sourced after init.lua, so wait for VimEnter or
-- typr's own definitions would overwrite these.
local function define_commands()
    vim.api.nvim_create_user_command("Typr", open, { desc = "Typing practice" })
    vim.api.nvim_create_user_command("TyprStats", stats, { desc = "Typing stats" })
end
if vim.v.vim_did_enter == 1 then
    define_commands()
else
    vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = define_commands })
end

vim.keymap.set("n", "<leader>Tt", open, { desc = "Typing practice (typr)" })
vim.keymap.set("n", "<leader>Ts", stats, { desc = "Typing stats (typr)" })
