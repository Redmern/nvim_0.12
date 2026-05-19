-- Horizontal split (never auto-closes on focus loss). The "rounded border"
-- is faked via a winbar with a top corner line — gives the look without the
-- float-window close-on-wincmd quirk.
require("toggleterm").setup({
    direction = "horizontal",
    size = 15,
    close_on_exit = true,
    shell = vim.o.shell,
})

-- Bind both keycodes — most terminals send Ctrl+/ as <C-_> (ASCII control byte),
-- while WezTerm/kitty/foot send the literal <C-/>. Mapping both covers all cases.
for _, key in ipairs({ "<C-/>", "<C-_>" }) do
    vim.keymap.set({ "n", "t" }, key, "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
end

