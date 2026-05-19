# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

User-facing install/keymap docs live in [`README.md`](./README.md). This file
focuses on **how the code is organized** — read it before changing structure.

## What this is

Personal Neovim 0.12 config. Uses the **built-in `vim.pack` plugin manager** (new in 0.12) — no lazy.nvim, no packer. Entry point `init.lua` → `lua/config/options` → `lua/plugins` → `lua/config/{autocmds,keymaps}`.

## Run / test

No build, no tests. Iterate by:

- `nvim` — load config. Errors surface at startup.
- `:checkhealth` — diagnose plugin/LSP/treesitter state.
- `vim.pack` has no UI: plugins live in `~/.local/share/nvim_0.12/site/pack/core/opt/`. Lockfile = `nvim-pack-lock.json`.
- Reload single file in running nvim: `:source %`.

## Architecture

**Plugin loading is split across two files:**

- `lua/plugins/specs.lua` — single list of `{ src = "...", name?, version? }` entries; returned to `vim.pack.add`. **Add a new plugin here.**
- `lua/plugins/init.lua` — dispatcher: feeds the specs to `vim.pack`, then `require`s each `lua/plugins/<name>.lua` in a deliberate order (e.g. `blink` before `lsp`, so capabilities exist when servers attach). Each `require` is `pcall`ed so one broken plugin doesn't kill startup.

Adding a plugin = three edits:
1. Append entry to `specs.lua`.
2. Create `lua/plugins/<name>.lua` with the `setup` call + keymaps.
3. Append `<name>` to the `modules` list in `init.lua`.

**LSP** (`lua/plugins/lsp.lua`):
- Mason + mason-lspconfig (`crashdummyy` registry registered to host the Roslyn package).
- LSP capabilities from blink.cmp are pushed via `vim.lsp.config("*", ...)` **before** any `vim.lsp.enable()` call — that's the only place that gets the timing right.
- Global `LspAttach` autocmd installs `gd`/`gr`/`K`/`<leader>l{r,a,d,h,f}` and toggles inlay hints when the server supports them.
- Pull + push diagnostic handlers are wrapped to drop `IDE0005` / `CS8019` (noisy "unused using" hints). Add codes to `SILENCED_DIAG_CODES` to silence more.

**Diagnostics rendering**: end-of-line `●` for every diagnostic; cursor line additionally gets the full message via `tiny-inline-diagnostic.nvim`. Sign column off.

**.NET / Blazor debugging** (`lua/util/dotnet-debug.lua` + `lua/plugins/dap.lua`):
- `<leader>dd` = `dotnet run` in a detached tmux window (or toggleterm split fallback), then `<leader>da` attaches netcoredbg.
- `<leader>dF` = Azure Functions isolated-worker via `func start --dotnet-isolated-debug`, auto-attaches once worker is up.
- `dap-cs` is **not** used — it overwrites `dap.configurations.cs` and conflicts with the attach flow. We set the adapter + configurations manually in `dap.lua`.
- Requires `kernel.yama.ptrace_scope = 0` (bootstrap.sh persists it).

**Omarchy theme sync** (`lua/config/autocmds.lua`):
- Reads `~/.config/omarchy/current/theme.name` (sibling `theme` is a *directory*, common pitfall — read `.name`).
- Re-runs on `FocusGained`. Omarchy's `theme-set` hook also sends `:ThemeReload` over RPC.
- `LineNr`/`CursorLineNr` highlights re-applied on `ColorScheme` so theme switches don't wipe them.

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
