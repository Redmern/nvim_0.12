require("which-key").setup({
    preset = "helix",
    win = {
        border = "rounded",
        padding = { 1, 1 },
    }
})

require("which-key").add({
    { "<leader>f", group = "Find",        icon = { icon = "󰍉", color = "blue"   } },
    { "<leader>g", group = "Git",         icon = { icon = "󰊢", color = "orange" } },
    { "<leader>l", group = "LSP",         icon = { icon = "󰒓", color = "yellow" } },
    { "<leader>d", group = "Debug",       icon = { icon = "󰃤", color = "red"    } },
    { "<leader>b", group = "Buffer",      icon = { icon = "󰓩", color = "cyan"   } },
    { "<leader>c", group = "Claude Code", icon = { icon = "󰭹", color = "purple" } },
    { "<leader>o", group = "opencode",    icon = { icon = "󰈮", color = "green"  }, mode = { "n", "x", "t" } },
    { "<leader>e", desc  = "Toggle tree", icon = { icon = "󰉋", color = "green"  } },
    { "<leader>E", desc  = "Toggle oil",  icon = { icon = "󰉖", color = "green"  } },
    { "<leader>/", desc  = "Live grep",   icon = { icon = "󰱼", color = "blue"   } },
})
