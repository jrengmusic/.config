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

# $HOME is /home/<user> at this point — bootstrap.sh hasn't run yet.
# Use Windows home explicitly.
WIN_HOME="/c/Users/$(whoami)"
SSH_DIR="$WIN_HOME/.ssh"

# Resolve which key to use for GitHub:
# 1. IdentityFile from ~/.ssh/config Host github.com block
# 2. Common key name fallbacks
# 3. Prompt
resolve_github_key() {
    local config="$SSH_DIR/config"
    if [[ -f "$config" ]]; then
        # Extract IdentityFile from the github.com host block
        local key
        key=$(awk '
            /^[Hh]ost / { in_github = ($2 == "github.com") }
            in_github && /[Ii]dentity[Ff]ile/ { print $2; exit }
        ' "$config")
        if [[ -n "$key" ]]; then
            # Expand ~ to WIN_HOME (~ is /home/<user> here, not what we want)
            key="${key/#\~/$WIN_HOME}"
            echo "$key"
            return
        fi
    fi
    # Fallback: common key names
    local candidates=("id_ed25519_github" "id_ed25519" "id_rsa")
    for name in "${candidates[@]}"; do
        [[ -f "$SSH_DIR/$name" ]] && echo "$SSH_DIR/$name" && return
    done
}

SSH_KEY=$(resolve_github_key)

if [[ -n "$SSH_KEY" && -f "$SSH_KEY" ]]; then
    info "SSH key found: $SSH_KEY"
else
    warn "No SSH key found. Options:"
    echo ""
    echo "  a) Copy existing key:"
    echo "       mkdir -p $SSH_DIR"
    echo "       cp /path/to/key $SSH_DIR/"
    echo "       chmod 600 $SSH_DIR/<keyname>"
    echo ""
    echo "  b) Generate new key:"
    echo "       ssh-keygen -t ed25519 -C 'your@email.com' -f $SSH_DIR/id_ed25519_github"
    echo "       cat $SSH_DIR/id_ed25519_github.pub  # add to GitHub → Settings → SSH keys"
    echo ""
    read -r -p "Generate new SSH key now? [y/N] " gen
    if [[ "$gen" == "y" || "$gen" == "Y" ]]; then
        read -r -p "Email for key comment: " email
        mkdir -p "$SSH_DIR"
        ssh-keygen -t ed25519 -C "$email" -f "$SSH_DIR/id_ed25519_github"
        echo ""
        info "Public key (add to GitHub → Settings → SSH keys):"
        echo ""
        cat "$SSH_DIR/id_ed25519_github.pub"
        echo ""
        read -r -p "Press Enter once the key is added to GitHub..."
        SSH_KEY="$SSH_DIR/id_ed25519_github"
    fi
fi

# ============================================================================
# 4. Start SSH agent
# ============================================================================
step "4. Start SSH agent"

if [[ -z "$SSH_KEY" || ! -f "$SSH_KEY" ]]; then
    error "No SSH key available — cannot continue. Add a key and re-run."
    exit 1
fi

eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_KEY"
info "SSH agent started, key loaded: $SSH_KEY"

info "Testing GitHub connection..."
# ssh -T always exits 1 even on success (GitHub behavior).
# set +e so the assignment doesn't kill the script regardless of bash version.
set +e
SSH_TEST=$(ssh -T -o BatchMode=yes -o ConnectTimeout=10 git@github.com 2>&1)
set -e
if echo "$SSH_TEST" | grep -q "successfully authenticated"; then
    info "GitHub auth OK"
else
    warn "$SSH_TEST"
    warn "If you see 'Permission denied', the public key is not on GitHub yet:"
    warn "  cat ${SSH_KEY}.pub  →  https://github.com/settings/keys"
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

# Detect if already running as Administrator (group 544 = Administrators)
if id -G | grep -qw 544 2>/dev/null; then
    info "Running as Administrator — chaining to bootstrap.sh"
    exec bash "$BOOTSTRAP"
else
    warn "Not running as Administrator."
    echo ""
    echo "Launching bootstrap.sh elevated via UAC..."
    echo "(A UAC prompt will appear — click Yes)"
    echo ""
    # Convert MSYS path to Windows path for PowerShell
    BOOTSTRAP_WIN=$(cygpath -w "$BOOTSTRAP")
    BASH_WIN="C:\\msys64\\usr\\bin\\bash.exe"
    powershell.exe -Command "Start-Process '$BASH_WIN' -ArgumentList '--login','-c','bash \"$BOOTSTRAP_WIN\"' -Verb RunAs" 2>/dev/null || {
        warn "Auto-elevation failed. Run manually as Administrator:"
        echo ""
        echo "  bash $BOOTSTRAP"
        echo ""
    }
fi
