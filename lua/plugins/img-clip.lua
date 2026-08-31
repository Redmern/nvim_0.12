-- Paste an image from the system clipboard straight into the buffer: the file
-- is written next to the document and a filetype-appropriate link inserted.
-- Wayland: uses wl-paste (wl-clipboard). Run :checkhealth img-clip to verify.
require("img-clip").setup({
    default = {
        dir_path = "assets", -- <doc-dir>/assets/<name>.png
        relative_to_current_file = true, -- assets/ sits beside the file, not cwd
        file_name = "%Y-%m-%d-%H-%M-%S",
        prompt_for_file_name = true,
        insert_mode_after_paste = false,
        drag_and_drop = { enabled = true, insert_mode = false },
    },
    filetypes = {
        markdown = {
            url_encode_path = true,
            template = "![$CURSOR]($FILE_PATH)",
        },
    },
})

vim.keymap.set("n", "<leader>mi", "<cmd>PasteImage<cr>", { desc = "Markdown: paste image from clipboard" })
