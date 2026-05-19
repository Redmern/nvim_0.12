#!/usr/bin/env bash
#
# bootstrap.sh — install everything this nvim config needs on a fresh Linux.
# Idempotent: safe to re-run.
#
# Usage:
#   ./bootstrap.sh                # full bootstrap
#   ./bootstrap.sh --no-dotnet    # skip the .NET SDK + func tools
#   ./bootstrap.sh --no-ptrace    # skip the sysctl change (needs sudo)
#
set -euo pipefail

SKIP_DOTNET=0
SKIP_PTRACE=0
for arg in "$@"; do
    case "$arg" in
        --no-dotnet) SKIP_DOTNET=1 ;;
        --no-ptrace) SKIP_PTRACE=1 ;;
        -h|--help)
            sed -n '1,15p' "$0"; exit 0 ;;
    esac
done

# ---------------------------------------------------------------------------
# 1. Detect distro / package manager
# ---------------------------------------------------------------------------
PM=""
if   command -v pacman >/dev/null; then PM="pacman"
elif command -v apt    >/dev/null; then PM="apt"
elif command -v dnf    >/dev/null; then PM="dnf"
else
    echo "Unsupported distro. Install the deps listed in README.md manually." >&2
    exit 1
fi
echo "==> Detected package manager: $PM"

# ---------------------------------------------------------------------------
# 2. System packages
# ---------------------------------------------------------------------------
ARCH_PKGS=(neovim git curl gcc rustup nodejs npm ripgrep fd tmux ttf-jetbrains-mono-nerd)
DEB_PKGS=(neovim git curl build-essential rustup nodejs npm ripgrep fd-find tmux fonts-jetbrains-mono)
DNF_PKGS=(neovim git curl gcc-c++ rustup nodejs npm ripgrep fd-find tmux jetbrains-mono-fonts)

install_pkgs() {
    case "$PM" in
        pacman) sudo pacman -S --needed --noconfirm "${ARCH_PKGS[@]}" ;;
        apt)    sudo apt update && sudo apt install -y "${DEB_PKGS[@]}" ;;
        dnf)    sudo dnf install -y "${DNF_PKGS[@]}" ;;
    esac
}
echo "==> Installing system packages"
install_pkgs

# ---------------------------------------------------------------------------
# 3. Rust toolchain (needed for fff.nvim native backend)
# ---------------------------------------------------------------------------
if ! rustc --version >/dev/null 2>&1; then
    echo "==> Initialising rustup default stable toolchain"
    rustup default stable
fi

# ---------------------------------------------------------------------------
# 4. .NET SDK + Azure Functions Core Tools
# ---------------------------------------------------------------------------
if [ "$SKIP_DOTNET" -eq 0 ]; then
    if ! command -v dotnet >/dev/null; then
        echo "==> Installing .NET SDK"
        case "$PM" in
            pacman) sudo pacman -S --needed --noconfirm dotnet-sdk ;;
            apt)    sudo apt install -y dotnet-sdk-8.0 || echo "(install .NET 8+ manually)" ;;
            dnf)    sudo dnf install -y dotnet-sdk-8.0 ;;
        esac
    fi
    if ! command -v func >/dev/null; then
        echo "==> Installing Azure Functions Core Tools (npm)"
        sudo npm i -g azure-functions-core-tools@4 --unsafe-perm true || true
    fi
fi

# ---------------------------------------------------------------------------
# 5. ptrace_scope (lets netcoredbg attach to non-descendant dotnet processes)
# ---------------------------------------------------------------------------
if [ "$SKIP_PTRACE" -eq 0 ]; then
    if [ "$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo 1)" != "0" ]; then
        echo "==> Setting kernel.yama.ptrace_scope=0 (required for DAP attach)"
        sudo sysctl kernel.yama.ptrace_scope=0
        echo 'kernel.yama.ptrace_scope = 0' | sudo tee /etc/sysctl.d/10-ptrace.conf >/dev/null
    fi
fi

# ---------------------------------------------------------------------------
# 6. First nvim run — let vim.pack clone plugins, then build fff + parsers
# ---------------------------------------------------------------------------
APPNAME="${NVIM_APPNAME:-nvim_0.12}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME"
FFF_DIR="$DATA_DIR/site/pack/core/opt/fff.nvim"

echo "==> Bootstrapping plugins (this may take a minute)"
NVIM_APPNAME="$APPNAME" nvim --headless "+qa" 2>/dev/null || true

# nvim-treesitter was archived on `master`; we pin `main` in specs.lua, but
# vim.pack will clone whatever the remote HEAD is on first run. Force-switch
# to `main` so a future default-branch change can't strand the install.
TS_DIR="$DATA_DIR/site/pack/core/opt/nvim-treesitter"
if [ -d "$TS_DIR/.git" ]; then
    git -C "$TS_DIR" fetch --quiet origin main 2>/dev/null || true
    git -C "$TS_DIR" checkout --quiet main 2>/dev/null || true
    git -C "$TS_DIR" pull --ff-only --quiet 2>/dev/null || true
fi

if [ -d "$FFF_DIR" ] && [ ! -f "$FFF_DIR/target/release/libfff_nvim.so" ]; then
    echo "==> Building fff.nvim native backend"
    ( cd "$FFF_DIR" && cargo build --release --no-default-features )
fi

echo "==> Installing tree-sitter parsers"
# Parser list lives in lua/util/treesitter-parsers.lua so this stays in sync
# with the in-editor install() call at startup.
NVIM_APPNAME="$APPNAME" nvim --headless -c \
  'lua local h=require("nvim-treesitter").install(require("util.treesitter-parsers")); if h and h.wait then h:wait(300000) end' \
  -c 'qa!' 2>&1 | tail -5 || true

echo
echo "==> Done. Launch with: NVIM_APPNAME=$APPNAME nvim"
