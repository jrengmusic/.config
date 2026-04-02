#!/bin/bash
# ============================================================================
# pre-setup.sh — Bootstrap MSYS2 before .config is cloned
# ============================================================================
# Run this FIRST on a fresh MSYS2 install, before setup.sh.
# Installs only git + openssh so you can clone .config and run setup.sh.
#
# How to run on a fresh machine (no .config yet):
#   curl -fsSL https://raw.githubusercontent.com/jrengmusic/.config/main/pre-setup.sh | bash
#
# Or paste manually in MSYS2 shell (CLANGARM64 on ARM64, MINGW64 on x64).
# ============================================================================
set -e

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

info() { echo "${GREEN}[OK]${NC} $1"; }
warn() { echo "${YELLOW}[!!]${NC} $1"; }
step() { echo ""; echo "${GREEN}━━━ $1 ━━━${NC}"; }

step "1. Update pacman"
pacman -Syu --noconfirm

step "2. Install git + openssh"
pacman -S --noconfirm --needed git openssh
info "git: $(git --version)"
info "ssh: $(ssh -V 2>&1)"

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

step "4. Clone .config"

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

step "Done"

echo ""
echo "Run setup.sh next (as Administrator):"
echo ""
echo "  bash $CONFIG_DIR/setup.sh"
echo ""
