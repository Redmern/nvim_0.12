-- Automatic list continuation / renumbering for markdown. The buffer-local
-- keymaps that drive it live in lua/config/keymaps.lua's markdown FileType
-- block (kept next to the other <leader>m* markdown maps rather than split into
-- an ftplugin). This file is just the engine setup.
--
-- Deliberately NOT bound: insert <Tab>/<S-Tab> (blink.cmp owns those via its
-- super-tab preset) and normal <C-r> (redo). Indent inside a list uses the
-- native <C-t>/<C-d> in insert mode, wrapped to recalculate.
require("autolist").setup()
