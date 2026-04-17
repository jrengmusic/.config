#!/bin/bash
# ============================================================================
# bootstrap-macos.sh — macOS dev environment setup
# ============================================================================
# Supports:
#   - Apple Silicon (ARM64): Homebrew (/opt/homebrew)
#   - Intel (x86_64): MacPorts (/opt/local)
#
# Run:
#   bash ~/.config/bootstrap-macos.sh
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
# Preflight checks
# ============================================================================
step "Preflight checks"

if [[ "$(uname -s)" != "Darwin" ]]; then
    error "This script only runs on macOS. Exiting."
    exit 1
fi

ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
    PLATFORM="macos-arm"
    info "Platform: Apple Silicon (ARM64)"
else
    PLATFORM="macos-intel"
    info "Platform: Intel (x86_64)"
fi

# ============================================================================
# 1. Package manager
# ============================================================================
step "1. Package manager"

if [[ "$PLATFORM" == "macos-arm" ]]; then
    if command -v brew &>/dev/null; then
        info "Homebrew already installed"
    else
        warn "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
    PKG_INSTALL="brew install"
    PKG_CHECK="brew list"
else
    if command -v port &>/dev/null; then
        info "MacPorts already installed"
    else
        error "MacPorts not installed. Download from https://www.macports.org/install.php"
        error "Monterey requires the legacy installer."
        exit 1
    fi
    PKG_INSTALL="sudo port install"
    PKG_CHECK="port installed"
fi

# ============================================================================
# 2. Packages
# ============================================================================
step "2. Packages"

# Common packages (name may differ between brew/port)
if [[ "$PLATFORM" == "macos-arm" ]]; then
    PACKAGES=(
        git
        git-lfs
        neovim
        go
        node
        eza
        fzf
        bat
        fd
        ripgrep
        jq
        zsh-syntax-highlighting
        oh-my-posh
        zoxide
        tmux
        cmake
        ninja
        btop
    )
else
    PACKAGES=(
        git
        git-lfs
        neovim
        go
        nodejs22
        eza
        fzf
        bat
        fd
        ripgrep
        jq
        zsh-syntax-highlighting
        oh-my-posh
        zoxide
        tmux
        cmake
        ninja
        btop
    )
fi

for pkg in "${PACKAGES[@]}"; do
    if $PKG_CHECK "$pkg" &>/dev/null; then
        info "Already installed: $pkg"
    else
        warn "Installing: $pkg"
        $PKG_INSTALL "$pkg"
    fi
done

# ============================================================================
# 2b. goreleaser (via go install)
# ============================================================================
step "2b. goreleaser"

if command -v goreleaser &>/dev/null; then
    info "goreleaser already installed"
else
    warn "Installing goreleaser via go install..."
    GOBIN="$HOME/.local/bin" go install github.com/goreleaser/goreleaser/v2@latest
    info "goreleaser installed"
fi

# ============================================================================
# 3. bun
# ============================================================================
step "3. bun"

if command -v bun &>/dev/null; then
    info "bun already installed"
else
    warn "Installing bun..."
    curl -fsSL https://bun.sh/install | bash
    info "bun installed"
fi

# ============================================================================
# 4. nvm + node (fallback if not via package manager)
# ============================================================================
step "4. nvm"

export NVM_DIR="$HOME/.nvm"
if [[ -d "$NVM_DIR" ]]; then
    info "nvm already installed"
else
    warn "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    info "nvm installed"
fi

# ============================================================================
# 5. zsh dotfile symlinks
# ============================================================================
step "5. zsh dotfile symlinks"

link_dotfile() {
    local src="$1" dst="$2"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        info "Already symlinked: $dst"
    else
        [[ -e "$dst" && ! -L "$dst" ]] && rm -f "$dst"
        ln -sf "$src" "$dst"
        info "Symlinked: $dst → $src"
    fi
}

link_dotfile "$HOME/.config/zsh/zshrc"   "$HOME/.zshrc"
link_dotfile "$HOME/.config/zsh/zprofile" "$HOME/.zprofile"

# ============================================================================
# 6. Carol
# ============================================================================
step "6. Carol"

if [[ -d "$HOME/.carol" ]]; then
    info "~/.carol already exists"
else
    warn "Cloning carol..."
    git clone git@github.com:jrengmusic/carol.git "$HOME/.carol"
    info "Cloned carol to ~/.carol"
fi

# carol binary symlink
mkdir -p "$HOME/.local/bin"
CAROL_TARGET="$HOME/.carol/bin/carol"
CAROL_LINK="$HOME/.local/bin/carol"
if [[ -f "$CAROL_TARGET" ]]; then
    if [[ -L "$CAROL_LINK" && "$(readlink "$CAROL_LINK")" == "$CAROL_TARGET" ]]; then
        info "carol symlink already correct"
    else
        [[ -e "$CAROL_LINK" && ! -L "$CAROL_LINK" ]] && rm -f "$CAROL_LINK"
        ln -sf "$CAROL_TARGET" "$CAROL_LINK"
        info "Symlinked carol → $CAROL_TARGET"
    fi
else
    warn "carol binary not found at $CAROL_TARGET"
fi

# ============================================================================
# 7. Claude Code
# ============================================================================
step "7. Claude Code"

if command -v claude &>/dev/null; then
    info "claude already installed: $(which claude)"
else
    warn "Installing Claude Code via npm..."
    npm install -g @anthropic-ai/claude-code
    info "Claude Code installed"
fi

# ============================================================================
# 8. CLAUDE.md symlinks (SSOT from ~/.config)
# ============================================================================
step "8. CLAUDE.md symlinks"

# Global CLAUDE.md — ~/.claude/CLAUDE.md → ~/.config/claude/CLAUDE.md
mkdir -p "$HOME/.claude"
CLAUDE_MD_SRC="$HOME/.config/claude/CLAUDE.md"
CLAUDE_MD_DST="$HOME/.claude/CLAUDE.md"
if [[ -L "$CLAUDE_MD_DST" && "$(readlink "$CLAUDE_MD_DST")" == "$CLAUDE_MD_SRC" ]]; then
    info "Global CLAUDE.md symlink already correct"
else
    [[ -e "$CLAUDE_MD_DST" && ! -L "$CLAUDE_MD_DST" ]] && rm -f "$CLAUDE_MD_DST"
    ln -sf "$CLAUDE_MD_SRC" "$CLAUDE_MD_DST"
    info "Symlinked global CLAUDE.md → $CLAUDE_MD_SRC"
fi

# Global settings.json — ~/.claude/settings.json → ~/.config/claude/settings.json
# Portable keys only; machine-specific extraKnownMarketplaces stays in settings.local.json.
SETTINGS_SRC="$HOME/.config/claude/settings.json"
SETTINGS_DST="$HOME/.claude/settings.json"
if [[ -L "$SETTINGS_DST" && "$(readlink "$SETTINGS_DST")" == "$SETTINGS_SRC" ]]; then
    info "Global settings.json symlink already correct"
else
    [[ -e "$SETTINGS_DST" && ! -L "$SETTINGS_DST" ]] && rm -f "$SETTINGS_DST"
    ln -sf "$SETTINGS_SRC" "$SETTINGS_DST"
    info "Symlinked global settings.json → $SETTINGS_SRC"
fi

# Seed ~/.claude/settings.local.json with the per-machine carol marketplace
# entry if absent. Claude Code deep-merges local into user settings at read
# time, so extraKnownMarketplaces lives here (absolute path differs per OS).
SETTINGS_LOCAL="$HOME/.claude/settings.local.json"
if [[ ! -e "$SETTINGS_LOCAL" ]]; then
    cat > "$SETTINGS_LOCAL" <<EOF
{
  "extraKnownMarketplaces": {
    "carol-marketplace": {
      "source": {
        "source": "directory",
        "path": "$HOME/.carol"
      }
    }
  }
}
EOF
    info "Seeded settings.local.json with carol-marketplace → $HOME/.carol"
fi

# Project CLAUDE.md — ~/.config/CLAUDE.md → ~/.carol/CAROL.md
CAROL_MD_SRC="$HOME/.carol/CAROL.md"
CAROL_MD_DST="$HOME/.config/CLAUDE.md"
if [[ -L "$CAROL_MD_DST" && "$(readlink "$CAROL_MD_DST")" == "$CAROL_MD_SRC" ]]; then
    info "Project CLAUDE.md symlink already correct"
else
    [[ -e "$CAROL_MD_DST" && ! -L "$CAROL_MD_DST" ]] && rm -f "$CAROL_MD_DST"
    ln -sf "$CAROL_MD_SRC" "$CAROL_MD_DST"
    info "Symlinked project CLAUDE.md → $CAROL_MD_SRC"
fi

# ============================================================================
# 9. Neovim
# ============================================================================
step "9. Neovim"

info "nvim uses XDG_CONFIG_HOME (~/.config/nvim) by default on macOS"
echo ""
echo "Notes:"
echo "  - Mason will auto-install LSP servers on first launch"
echo "  - DAP adapter: codelldb (installed via Mason)"

# ============================================================================
# 10. END terminal
# ============================================================================
step "10. END terminal"

if [[ -f "$HOME/.local/bin/END" || -d "/Applications/END.app" ]]; then
    info "END found"
else
    warn "END not found. Build from ~/Documents/Poems/dev/end/ or copy to ~/.local/bin/"
fi

echo ""
echo "END terminal config: ~/.config/end/end.lua"

# ============================================================================
# Summary
# ============================================================================
step "Setup complete"

cat << EOF

Key paths:
  Config repo:    ~/.config/
  nvim config:    ~/.config/nvim
  CLI tools:      ~/.local/bin/ (carol)
  Carol:          ~/.carol/bin/carol
  Claude Code:    npm global (@anthropic-ai/claude-code)
  CLAUDE.md SSOT: ~/.config/claude/CLAUDE.md

EOF
