-- Inline variable values while stepping through code with DAP.
require("nvim-dap-virtual-text").setup({
    enabled = true,
    enabled_commands = true,
    highlight_changed_variables = true,
    show_stop_reason = true,
    virt_text_pos = "eol", -- end of line; switch to "inline" if your nvim renders it well
    commented = false,
})
