-- opencode.nvim — matches the old config's keymaps.
-- Falls back to vim.ui.input / vim.ui.select for prompts (noice already prettifies these).
-- Add folke/snacks.nvim to vim.pack and configure its input/picker modules if you want
-- the fancier popup UI that the old setup had.

---@type opencode.Opts
vim.g.opencode_opts = {}
vim.o.autoread = true -- required for opts.events.reload

local opencode = function() return require("opencode") end

-- <leader>o* — opencode
vim.keymap.set({ "n", "x" }, "<leader>oa", function() opencode().ask("@this: ", { submit = true }) end,
    { desc = "Ask opencode…" })
vim.keymap.set({ "n", "x" }, "<leader>os", function() opencode().select() end, { desc = "Execute opencode action…" })
vim.keymap.set({ "n", "t" }, "<leader>oo", function() opencode().toggle() end, { desc = "Toggle opencode" })
vim.keymap.set({ "n", "x" }, "<leader>or", function() return opencode().operator("@this ") end,
    { desc = "Add range to opencode", expr = true })
vim.keymap.set("n", "<leader>ol", function() return opencode().operator("@this ") .. "_" end,
    { desc = "Add line to opencode", expr = true })
vim.keymap.set("n", "<leader>ou", function() opencode().command("session.half.page.up") end,
    { desc = "Scroll opencode up" })
vim.keymap.set("n", "<leader>od", function() opencode().command("session.half.page.down") end,
    { desc = "Scroll opencode down" })
