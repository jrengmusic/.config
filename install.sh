#!/bin/bash
# ============================================================================
# install.sh — One-shot Windows dev environment install
# ============================================================================
# Run on a fresh MSYS2 install (no .config repo yet).
# Bootstraps git + openssh, clones .config, then chains to bootstrap.sh.
#
# One-liner (no Admin needed for this script):
#   curl -fsSL https://raw.githubusercontent.com/jrengmusic/.config/main/install.sh | bash
#
# Launch the correct shell first:
#   ARM64 Windows → MSYS2 CLANGARM64
#   x64 Windows   → MSYS2 MINGW64
# ============================================================================
set -e

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

info() { echo "${GREEN}[OK]${NC} $1"; }
warn() { echo "${YELLOW}[!!]${NC} $1"; }
error() { echo "${RED}[ERR]${NC} $1"; }
step() { echo ""; echo "${GREEN}━━━ $1 ━━━${NC}"; }

# ============================================================================
# 1. Update pacman
# ============================================================================
step "1. Update pacman"
pacman -Syu --noconfirm

# ============================================================================
# 2. Install git + openssh
# ============================================================================
step "2. Install git + openssh"
pacman -S --noconfirm --needed git openssh
info "git: $(git --version)"
info "ssh: $(ssh -V 2>&1)"

# ============================================================================
# 3. SSH key
# ============================================================================
step "3. SSH key"

SSH_KEY="$HOME/.ssh/id_ed25519"
if [[ -f "$SSH_KEY" ]]; then
    info "SSH key already exists at $SSH_KEY"
else
    warn "No SSH key found. Options:"
    echo ""
    echo "  a) Copy existing key:"
    echo "       mkdir -p ~/.ssh"
    echo "       cp /path/to/id_ed25519 ~/.ssh/"
    echo "       cp /path/to/id_ed25519.pub ~/.ssh/"
    echo "       chmod 600 ~/.ssh/id_ed25519"
    echo ""
    echo "  b) Generate new key:"
    echo "       ssh-keygen -t ed25519 -C 'your@email.com'"
    echo "       cat ~/.ssh/id_ed25519.pub  # add to GitHub → Settings → SSH keys"
    echo ""
    read -r -p "Generate new SSH key now? [y/N] " gen
    if [[ "$gen" == "y" || "$gen" == "Y" ]]; then
        read -r -p "Email for key comment: " email
        ssh-keygen -t ed25519 -C "$email"
        echo ""
        info "Public key (add to GitHub → Settings → SSH keys):"
        echo ""
        cat ~/.ssh/id_ed25519.pub
        echo ""
        read -r -p "Press Enter once the key is added to GitHub..."
    fi
fi

# ============================================================================
# 4. Start SSH agent
# ============================================================================
step "4. Start SSH agent"

eval "$(ssh-agent -s)" > /dev/null
ssh-add ~/.ssh/id_ed25519
info "SSH agent started, key loaded"

info "Testing GitHub connection..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    info "GitHub auth OK"
else
    warn "If you see 'Hi <user>! You've successfully authenticated' above, auth is fine."
    warn "If you see 'Permission denied', the public key is not on GitHub yet:"
    warn "  cat ~/.ssh/id_ed25519.pub  →  https://github.com/settings/keys"
    read -r -p "Press Enter to continue anyway, or Ctrl-C to abort..."
fi

# ============================================================================
# 5. Clone .config
# ============================================================================
step "5. Clone .config"

WIN_HOME="/c/Users/$(whoami)"
CONFIG_DIR="$WIN_HOME/.config"

if [[ -d "$CONFIG_DIR/.git" ]]; then
    info ".config already cloned at $CONFIG_DIR"
else
    info "Cloning to $CONFIG_DIR ..."
    cd "$WIN_HOME"
    git clone git@github.com:jrengmusic/.config.git .config
    info "Cloned."
fi

# ============================================================================
# 6. Chain to bootstrap.sh
# ============================================================================
step "6. bootstrap.sh"

BOOTSTRAP="$CONFIG_DIR/bootstrap.sh"

# Detect if already running as Administrator
if net session &>/dev/null 2>&1; then
    info "Running as Administrator — chaining to bootstrap.sh"
    exec bash "$BOOTSTRAP"
else
    echo ""
    warn "Not running as Administrator."
    echo ""
    echo "Relaunch MSYS2 as Administrator, then run:"
    echo ""
    echo "  bash $BOOTSTRAP"
    echo ""
fi
