# Pending decisions (needs red)

Two things left intentionally untouched because they're judgement calls, not
clear bugs. Decide and either fix or document.

## (a) `razor` in roslyn filetypes vs. the "Razor off" note

`lua/plugins/lsp.lua` sets `filetypes = { "cs", "razor" }` on `roslyn_ls`
(~L83), but CLAUDE.md and the surrounding notes say Razor LSP stays **off**
because the current binary crashes on the razor args (treesitter still
highlights `.razor`). These contradict each other.

Decide: is attaching `roslyn_ls` to `razor` buffers intended (and the note
stale), or should `razor` be dropped from the filetypes list?

## (b) Raw `<C-h>` passthrough inside AI panels (tmux-navigator)

`lua/plugins/tmux-navigator.lua` — whether a raw `Ctrl-h` should pass through
to the application (e.g. delete-word / pane-internal nav) while focus is inside
an AI panel (claudecode / omp terminal), instead of being captured as a
tmux/window navigation key. Left as-is; confirm the desired behaviour.
