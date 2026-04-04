#!/bin/bash
# ============================================================================
# install.sh — Universal dev environment installer
# ============================================================================
# Detects OS/arch, bootstraps prerequisites, clones .config, then dispatches
# to the appropriate bootstrap-<os>.sh script.
#
# Supports:
#   macOS ARM64  (MBP M4)          → Homebrew
#   macOS x86_64 (iMac 5K 2015)    → MacPorts
#   Windows x64  (Bootcamp, ROG)   → MSYS2/MINGW64
#   Windows ARM64 (UTM)            → MSYS2/CLANGARM64
#
# Fresh machine (no .config yet):
#   curl -fsSL https://raw.githubusercontent.com/jrengmusic/.config/main/install.sh | bash
#
# Existing machine (fix SSOT, re-bootstrap):
#   bash ~/.config/install.sh
# ============================================================================
set -e

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

info()  { echo "${GREEN}[OK]${NC} $1"; }
warn()  { echo "${YELLOW}[!!]${NC} $1"; }
error() { echo "${RED}[ERR]${NC} $1"; }
step()  { echo ""; echo "${GREEN}━━━ $1 ━━━${NC}"; }

# ============================================================================
# 1. Detect OS and architecture
# ============================================================================
step "1. Detect OS / architecture"

OS=""
ARCH=""
BOOTSTRAP_SCRIPT=""

case "$(uname -s)" in
    Darwin)
        OS="macos"
        ARCH="$(uname -m)"
        BOOTSTRAP_SCRIPT="bootstrap-macos.sh"
        if [[ "$ARCH" == "arm64" ]]; then
            info "macOS ARM64 (Apple Silicon)"
        else
            info "macOS x86_64 (Intel)"
        fi
        ;;
    *MINGW*|*MSYS*|*CYGWIN*)
        OS="windows"
        BOOTSTRAP_SCRIPT="bootstrap-windows.sh"
        # MSYSTEM is canonical for Windows arch detection (see bootstrap-windows.sh)
        case "$MSYSTEM" in
            CLANGARM64)
                ARCH="arm64"
                info "Windows ARM64 (CLANGARM64)"
                ;;
            *)
                ARCH="x64"
                info "Windows x64 ($MSYSTEM)"
                ;;
        esac
        ;;
    *)
        error "Unsupported OS: $(uname -s)"
        exit 1
        ;;
esac

# ============================================================================
# 2. Resolve home directory
# ============================================================================
step "2. Home directory"

if [[ "$OS" == "windows" ]]; then
    # MSYS2 home may be /home/<user> before nsswitch is configured
    USER_HOME="/c/Users/$(whoami)"
else
    USER_HOME="$HOME"
fi
CONFIG_DIR="$USER_HOME/.config"
info "Home: $USER_HOME"
info "Config: $CONFIG_DIR"

# ============================================================================
# 3. Ensure git + SSH (Windows needs explicit install, macOS has Xcode CLT)
# ============================================================================
step "3. Prerequisites"

if [[ "$OS" == "windows" ]]; then
    # Update pacman and install git + openssh
    pacman -Syu --noconfirm
    pacman -S --noconfirm --needed git openssh
    info "git: $(git --version)"
    info "ssh: $(ssh -V 2>&1)"
elif [[ "$OS" == "macos" ]]; then
    # Xcode CLT provides git; prompt install if missing
    if ! command -v git &>/dev/null; then
        warn "Installing Xcode Command Line Tools (provides git)..."
        xcode-select --install
        echo "Press Enter after Xcode CLT finishes installing..."
        read -r
    fi
    info "git: $(git --version)"
fi

# ============================================================================
# 4. SSH key (for cloning private repos)
# ============================================================================
step "4. SSH key"

if [[ "$OS" == "windows" ]]; then
    WIN_HOME="/c/Users/$(whoami)"
    SSH_DIR="$WIN_HOME/.ssh"
else
    SSH_DIR="$USER_HOME/.ssh"
fi

# Resolve which key to use for GitHub
resolve_github_key() {
    local config="$SSH_DIR/config"
    if [[ -f "$config" ]]; then
        local key
        key=$(awk '
            /^[Hh]ost / { in_github = ($2 == "github.com") }
            in_github && /[Ii]dentity[Ff]ile/ { print $2; exit }
        ' "$config")
        if [[ -n "$key" ]]; then
            key="${key/#\~/$USER_HOME}"
            echo "$key"
            return
        fi
    fi
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

# Start SSH agent only if not already functional
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    info "SSH already authenticated with GitHub"
elif [[ -n "$SSH_KEY" && -f "$SSH_KEY" ]]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add "$SSH_KEY" 2>/dev/null
    info "SSH agent started, key loaded"
fi

# ============================================================================
# 5. Clone .config (if not already present)
# ============================================================================
step "5. Clone .config"

if [[ -d "$CONFIG_DIR/.git" ]]; then
    info ".config already cloned at $CONFIG_DIR"
else
    if [[ -z "$SSH_KEY" || ! -f "$SSH_KEY" ]]; then
        error "No SSH key available — cannot clone. Add a key and re-run."
        exit 1
    fi
    info "Cloning to $CONFIG_DIR ..."
    git clone git@github.com:jrengmusic/.config.git "$CONFIG_DIR"
    info "Cloned."
fi

# ============================================================================
# 6. Dispatch to OS-specific bootstrap
# ============================================================================
step "6. Dispatch → $BOOTSTRAP_SCRIPT"

BOOTSTRAP="$CONFIG_DIR/$BOOTSTRAP_SCRIPT"

if [[ ! -f "$BOOTSTRAP" ]]; then
    error "Bootstrap script not found: $BOOTSTRAP"
    exit 1
fi

if [[ "$OS" == "windows" ]]; then
    # Windows bootstrap needs Administrator for system PATH, env vars, nsswitch
    if id -G | grep -qw 544 2>/dev/null; then
        info "Running as Administrator — chaining to $BOOTSTRAP_SCRIPT"
        exec bash "$BOOTSTRAP"
    else
        warn "Not running as Administrator."
        echo ""
        echo "Launching $BOOTSTRAP_SCRIPT elevated via UAC..."
        echo "(A UAC prompt will appear — click Yes)"
        echo ""
        BOOTSTRAP_WIN=$(cygpath -w "$BOOTSTRAP")
        BASH_WIN="C:\\msys64\\usr\\bin\\bash.exe"
        powershell.exe -Command "Start-Process '$BASH_WIN' -ArgumentList '--login','-c','bash \"$BOOTSTRAP_WIN\"' -Verb RunAs" 2>/dev/null || {
            warn "Auto-elevation failed. Run manually as Administrator:"
            echo ""
            echo "  bash $BOOTSTRAP"
            echo ""
        }
    fi
else
    info "Chaining to $BOOTSTRAP_SCRIPT"
    exec bash "$BOOTSTRAP"
fi
