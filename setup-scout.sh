#!/bin/bash
# ============================================================================
# setup-scout.sh — password-free kernel sampling for scout
# ============================================================================
# macOS:   root-owned /opt/scout/scout + sudoers rule (NOPASSWD, scout only)
# Linux:   root-owned /opt/scout/scout + file capabilities (no sudo at run)
# Windows: nothing to configure (admin terminal, UAC consent only)
#
# Idempotent. Run:
#   bash ~/.config/setup-scout.sh [path/to/built/scout]
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

SCOUT_SOURCE="${1:-$HOME/Documents/Poems/dev/scout/Builds/Release/scout_artefacts/Release/scout}"
SCOUT_DIRECTORY="/opt/scout"
SCOUT_INSTALLED="$SCOUT_DIRECTORY/scout"
SUDOERS_FILE="/etc/sudoers.d/scout"
SCOUT_USER="$(id -un)"

install_binary() {
    local group="$1"
    sudo install -d -o root -g "$group" -m 755 "$SCOUT_DIRECTORY"
    sudo install -o root -g "$group" -m 755 "$SCOUT_SOURCE" "$SCOUT_INSTALLED"
    info "Installed $SCOUT_INSTALLED (root:$group 755)"
}

setup_macos() {
    install_binary wheel

    local temporary
    temporary="$(mktemp)"
    echo "$SCOUT_USER ALL=(root) NOPASSWD: $SCOUT_INSTALLED" > "$temporary"
    sudo visudo -cf "$temporary"
    sudo install -o root -g wheel -m 440 "$temporary" "$SUDOERS_FILE"
    rm -f "$temporary"
    info "Sudoers rule: $SUDOERS_FILE"
}

setup_linux() {
    install_binary root
    sudo setcap cap_perfmon,cap_dac_read_search+ep "$SCOUT_INSTALLED"
    info "Capabilities: $(getcap "$SCOUT_INSTALLED")"
}

step "scout kernel sampling setup"

if [[ -f "$SCOUT_SOURCE" ]]; then
    case "$(uname -s)" in
        Darwin) setup_macos ;;
        Linux)  setup_linux ;;
        *MINGW*|*MSYS*|*CYGWIN*) info "Windows: nothing to configure (admin terminal, UAC consent only)" ;;
        *) error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
else
    error "scout binary not found: $SCOUT_SOURCE"
    exit 1
fi
