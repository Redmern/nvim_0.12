# nvim_0.12

Personal Neovim 0.12 configuration. Uses the built-in `vim.pack` plugin
manager — no lazy.nvim, no packer. Themed via Omarchy if installed,
catppuccin/dark otherwise.

> If you're hacking on this config (or you're Claude Code reading it), see
> [`CLAUDE.md`](./CLAUDE.md) for how the code is organized — load order,
> per-plugin invariants, debugging flow.

> `nvim-pack-lock.json` is **tracked in git** intentionally. It pins the
> exact commit of every plugin so two machines get the same setup. Run
> `:lua vim.pack.update()` then commit the updated lockfile when you want
> to bump versions.

## Quick start

On a fresh Linux box:

```sh
git clone <this-repo> ~/.config/nvim_0.12
cd ~/.config/nvim_0.12
./bootstrap.sh
NVIM_APPNAME=nvim_0.12 nvim
```

Add this to `~/.zshrc` / `~/.bashrc` if you want a shortcut:

```sh
alias v='NVIM_APPNAME=nvim_0.12 nvim'
```

## What the bootstrap script does

`bootstrap.sh` is idempotent — re-runnable. It detects your distro
(`pacman` / `apt` / `dnf`) and:

1. Installs system packages: `neovim`, `git`, `curl`, a C compiler,
   `rustup`, `nodejs`, `npm`, `ripgrep`, `fd`, `tmux`, JetBrains Mono Nerd Font.
2. Initialises the Rust stable toolchain (needed to build the fff.nvim
   native backend).
3. Installs the .NET SDK and Azure Functions Core Tools (`func`).
4. Sets `kernel.yama.ptrace_scope = 0` and persists it in
   `/etc/sysctl.d/10-ptrace.conf` — required so `netcoredbg` can attach
   to a running `dotnet` process.
5. Runs `nvim --headless` once so `vim.pack` clones every plugin and
   Mason installs `lua_ls`, `netcoredbg`, `csharpier`, `stylua`,
   `js-debug-adapter`.
6. Builds the fff.nvim Rust crate without the `zlob` feature (avoids
   needing Zig on the system).
7. Compiles the tree-sitter parsers we use
   (C#, Lua, Bash, JSON, YAML, Vim, Markdown, HTML/CSS/JS/TS, Python,
   Go, Rust, TOML, XML, SQL, Dockerfile, …).

### Flags

```
./bootstrap.sh --no-dotnet   # skip the .NET SDK + func install
./bootstrap.sh --no-ptrace   # skip the sysctl change (needs sudo)
```

## Manual steps if you skip the script

If you'd rather install things yourself, you need on `PATH`:

| Tool          | Why                                                     |
|---------------|---------------------------------------------------------|
| `neovim ≥0.12`| `vim.pack`, new tree-sitter ABI                         |
| `git`, `curl` | plugin cloning, Mason downloads                         |
| `cc` (gcc)    | tree-sitter parser compilation                          |
| `cargo`       | builds fff.nvim's Rust backend                          |
| `node`, `npm` | Mason LSP installers, js-debug-adapter                  |
| `ripgrep`,`fd`| telescope live_grep, fff, oil                           |
| `tmux`        | `<leader>dd` spawns `dotnet run` in a tmux window       |
| Nerd Font     | icons in bufferline, neo-tree, lualine, which-key       |
| `dotnet`      | .NET SDK for C# debugging / formatting                  |
| `func`        | only if you debug Azure Functions (`<leader>dF`)        |

Then run, once:

```sh
# 1. clone plugins
NVIM_APPNAME=nvim_0.12 nvim --headless "+qa"

# 2. build fff (Zig not needed with --no-default-features)
cd ~/.local/share/nvim_0.12/site/pack/core/opt/fff.nvim
cargo build --release --no-default-features

# 3. compile tree-sitter parsers
NVIM_APPNAME=nvim_0.12 nvim --headless \
  -c 'lua require("nvim-treesitter").install({"c_sharp","lua","bash","json","yaml","vim","vimdoc","markdown","markdown_inline","html","css","javascript","typescript","tsx","python","go","rust","toml","xml","sql","dockerfile","regex","query"}):wait(300000)' \
  -c 'qa!'

# 4. allow netcoredbg to attach
sudo sysctl kernel.yama.ptrace_scope=0
echo 'kernel.yama.ptrace_scope = 0' | sudo tee /etc/sysctl.d/10-ptrace.conf
```

## Highlights

| Keymap          | Action                                            |
|-----------------|---------------------------------------------------|
| `<Space>` (leader) — `<leader>e` | toggle file tree (neo-tree) |
| `<leader>E`     | toggle file tree (oil)                            |
| `<leader><space>` | fuzzy find files (fff)                          |
| `<leader>/`     | live grep (fff)                                   |
| `<leader>dd`    | build + `dotnet run` in tmux, then `<leader>da`   |
| `<leader>dF`    | `func start --dotnet-isolated-debug` + auto-attach|
| `<leader>da`    | attach netcoredbg to a running dotnet PID         |
| `<leader>du`    | toggle dap-ui panels                              |
| `<leader>de`/`dw`| peek value under cursor (eval popup)             |
| `<F5>`/`<F9>`/`<F10>`/`<F11>` | DAP continue / breakpoint / over / into |
| `<C-/>` or `<C-_>` | toggle a horizontal terminal                   |
| `<C-h/j/k/l>`   | move between nvim splits (and tmux panes)         |

`<leader>` opens the which-key popup — every chord is discoverable from
there.

## File layout

```
init.lua                    — leader + load order
lua/config/options.lua      — vim options, plugin globals (netrw off,
                              tmux-navigator no_mappings, etc.)
lua/config/autocmds.lua     — Omarchy theme sync, line-number colours
lua/config/keymaps.lua      — non-plugin keymaps
lua/plugins/init.lua        — `vim.pack.add` list + `require` order
lua/plugins/<plugin>.lua    — one file per plugin's setup
lua/util/dotnet-debug.lua   — `<leader>dd`/`dF` workflow helpers
```

Adding a new plugin = three edits:

1. Append it to `vim.pack.add(...)` in `lua/plugins/init.lua`.
2. Create `lua/plugins/<name>.lua` with its `setup` + keymaps.
3. Add `require("plugins.<name>")` in `lua/plugins/init.lua`.

## Troubleshooting

- **`attempt to call method 'range'` from tree-sitter** — plugin is on
  the archived `master` branch. Wipe and let it re-clone:
  `rm -rf ~/.local/share/nvim_0.12/site/pack/core/opt/nvim-treesitter`,
  then restart.
- **`Failed to load fff rust backend`** — run step 2 of the manual
  steps. Needs `cargo`; the `--no-default-features` flag skips Zig.
- **Breakpoints stay grey** — check
  `cat /proc/sys/kernel/yama/ptrace_scope` (must be `0`). Run step 4.
- **No icons / boxes everywhere** — set your terminal font to a Nerd
  Font (the bootstrap installs JetBrains Mono Nerd).
- **`No .csproj found` on `<leader>dd`** — open a file inside the
  project first; the helper walks up from the buffer's path.
