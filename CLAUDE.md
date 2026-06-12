# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

User-facing install/keymap docs live in [`README.md`](./README.md). This file
focuses on **how the code is organized** — read it before changing structure.

## What this is

Personal Neovim 0.12 config. Uses the **built-in `vim.pack` plugin manager** (new in 0.12) — no lazy.nvim, no packer. Entry point `init.lua` → `lua/config/options` → `lua/plugins` → `lua/config/{autocmds,keymaps}`.

## Run / test

The config itself has no build and no test suite. Iterate by:

- `nvim` — load config. Errors surface at startup.
- `:checkhealth` — diagnose plugin/LSP/treesitter state.
- `vim.pack` has no UI: plugins live in `~/.local/share/nvim_0.12/site/pack/core/opt/`. Lockfile = `nvim-pack-lock.json`.
- Reload single file in running nvim: `:source %`.

It *does* ship a C# test runner for the projects you edit: `neotest` +
`neotest-dotnet` (`lua/plugins/neotest.lua`). `<leader>tn` runs the nearest
test, `<leader>tt` the file, `<leader>td` debugs the nearest test under DAP.
`discovery_root = "solution"` treats the whole `.sln`/`.slnx` as one project.

## Architecture

**Plugin loading is split across two files:**

- `lua/plugins/specs.lua` — single list of `{ src = "...", name?, version? }` entries; returned to `vim.pack.add`. **Add a new plugin here.**
- `lua/plugins/init.lua` — dispatcher: feeds the specs to `vim.pack`, then `require`s each `lua/plugins/<name>.lua` in a deliberate order (e.g. `blink` before `lsp`, so capabilities exist when servers attach). Each `require` is `pcall`ed so one broken plugin doesn't kill startup.

Adding a plugin = three edits:
1. Append entry to `specs.lua`.
2. Create `lua/plugins/<name>.lua` with the `setup` call + keymaps.
3. Append `<name>` to the `modules` list in `init.lua`.

**LSP** (`lua/plugins/lsp.lua`):
- Mason registers the `crashdummyy` registry, which hosts the `roslyn` package. `lua_ls` + `bicep` go through `mason-lspconfig`; **C# does not** — the `roslyn` binary is installed (and version-**pinned**, currently `5.8.0-...`) by `mason-tool-installer` in `dap.lua`. Bump it deliberately, not on every `:MasonUpdate`.
- The C# server is started by `vim.lsp.enable("roslyn_ls")` with config via `vim.lsp.config("roslyn_ls", ...)` directly in `lsp.lua` — **`roslyn.nvim` is not used**; `lua/plugins/roslyn.lua` is a commented-out stub kept as a breadcrumb. Razor LSP stays off (current binary crashes on the razor args); treesitter still highlights `.razor`.
- LSP capabilities from blink.cmp are pushed via `vim.lsp.config("*", ...)` **before** any `vim.lsp.enable()` call — that's the only place that gets the timing right.
- Global `LspAttach` autocmd installs `gd`/`gr`/`K`/`<leader>l{r,a,d,h}` and toggles inlay hints when the server supports them.
- Pull + push diagnostic handlers are wrapped to drop `IDE0005` / `CS8019` (noisy "unused using" hints). Add codes to `SILENCED_DIAG_CODES` to silence more.

**Formatting** (`lua/plugins/conform.lua`): `csharpier`/`stylua`/`prettier` by filetype, format-on-save with `lsp_fallback`. `<leader>lf` formats manually. `:FormatDisable[!]` / `:FormatEnable` toggle the save hook globally (or per-buffer with `!`).

**Diagnostics rendering**: end-of-line `●` for every diagnostic; cursor line additionally gets the full message via `tiny-inline-diagnostic.nvim`. Sign column off.

**.NET / Blazor debugging** (`lua/util/dotnet-debug.lua` + `lua/plugins/dap.lua`):
- `<leader>dd` = `dotnet run` in a detached tmux window (or toggleterm split fallback), then `<leader>da` attaches netcoredbg.
- `<leader>dF` = Azure Functions isolated-worker via `func start --dotnet-isolated-debug`, auto-attaches once worker is up.
- `dap-cs` is **not** used — it overwrites `dap.configurations.cs` and conflicts with the attach flow. We set the adapter + configurations manually in `dap.lua`.
- Requires `kernel.yama.ptrace_scope = 0` (bootstrap.sh persists it).

**Godot (C#/Mono) debugging** (`lua/util/godot-debug.lua` + `<leader>G*` in `dap.lua`):
- Mirrors the .NET flow. `godot-mono` embeds .NET, so netcoredbg attaches to its PID the same way as a `dotnet run` process. Runs in a toggleterm split (keeps `GD.Print` visible).
- `<leader>Gr` run game, `<leader>Gd` debug (build + run + auto-attach once `godot-mono` is up), `<leader>Ga` attach to running, `<leader>Ge` open editor, `<leader>Gb` build, `<leader>Gi` re-import assets, `<leader>GS` stop.
- `find_pid` skips the Godot **editor** process (`--editor`/`-e`) so it attaches to the running game; build target prefers `.sln` over `.csproj` (avoids MSB1011).

**Omarchy theme sync** (`lua/config/autocmds.lua`):
- Reads `~/.config/omarchy/current/theme.name` (sibling `theme` is a *directory*, common pitfall — read `.name`).
- Re-runs on `FocusGained`. Omarchy's `theme-set` hook also sends `:ThemeReload` over RPC.
- `LineNr`/`CursorLineNr` highlights re-applied on `ColorScheme` so theme switches don't wipe them.

**Transparency / "always run in tmux" invariant** (`lua/config/autocmds.lua` `make_transparent()`, plus the `v` zsh function in `~/.zshrc`):
- Ghostty bug [#8642](https://github.com/ghostty-org/ghostty/issues/8642): under `background-opacity < 1`, cells with explicit colored bg render *more opaque* than `bg=NONE` cells → nvim chrome looks like patchy blocks outside tmux. tmux flattens default-bg cells, hiding the bug.
- `make_transparent()` strips bg from chrome groups (`Normal`, `StatusLine`, `WinBar`, `^BufferLine`, `^TabLine`, `^WinBar`, `^lualine_`, neo-tree Normal). **The statusline is a foreground-only design** (`plugins/lualine.lua`: colored bold mode text + glyph accents, custom bg-free theme) — Ghostty's unfixed blend bug ([#7957](https://github.com/ghostty-org/ghostty/issues/7957), still broken in 1.3.1, fix PRs closed unmerged) mangles explicit-bg cells outside tmux, and fg-only is the only style that renders identically in and out of tmux. Don't reintroduce section backgrounds/pills while that bug is unfixed. If a future Ghostty release fixes #7957, pills become viable again together with `background-opacity-cells = true` in ghostty config (a note is parked there).
- The user's `v` shell function always launches nvim inside tmux for the same reason. Don't suggest reverting it to a plain alias.

**Window-layout invariants:**
- `vim.o.equalalways = false` globally.
- neo-tree + claudecode + opencode get `winfixwidth = true` so the central code area is the only one that resizes when buffers open/close.
- `:bd` / `:bdelete` are aliased to `:BD`, which is layout-preserving (switches to another buffer instead of closing the window).

**Treesitter parser list** lives in `lua/util/treesitter-parsers.lua` and is consumed by both `plugins/treesitter.lua` (startup install) and `bootstrap.sh` (fresh install). Don't add a new parser in two places.

**Completion:** `blink.cmp` v2 with sources `{ lsp, lazydev, path, buffer }` and cmdline completion. Ghost text is owned by `supermaven.nvim`; blink's `ghost_text` is disabled.

**Leader = Space.** Set in `init.lua` *before* plugins load.

## Conventions

- New plugin config files: lowercase, hyphenated, matching the require path (`lua/plugins/foo-bar.lua` → `require("plugins.foo-bar")`).
- `lua/plugins/init.lua` only dispatches; never put setup code there.
- `pcall` around colorscheme + plugin requires so a missing dep doesn't break startup.
- Anything that affects every LSP server (capabilities, handlers) goes in `lua/plugins/lsp.lua` so the load order is centralised.
