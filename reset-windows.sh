#!/bin/bash
# ============================================================================
# reset.sh — Undo everything bootstrap.sh did
# ============================================================================
# Returns machine to blank MSYS2 + git state.
# Run from MSYS2 MinGW64 or CLANGARM64 shell as Administrator:
#   bash ~/.config/reset.sh
#
# After running, only MSYS2 base + git remain. ~/.config/ is NOT deleted
# (you need it to re-run setup).
#
# Supports x64 (MINGW64) and ARM64 (CLANGARM64). Architecture is auto-detected
# via PROCESSOR_ARCHITECTURE — uname -m is unreliable on ARM64 Windows.
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
# Preflight
# ============================================================================
step "Preflight"

if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" ]]; then
    error "This script only runs on Windows (MSYS2). Exiting."
    exit 1
fi

WINDOWS_HOME="/c/Users/$(whoami)"
WIN_HOME="C:\\Users\\$(whoami)"

if [[ ! -d "$WINDOWS_HOME" ]]; then
    error "Windows home not found at $WINDOWS_HOME"
    exit 1
fi

# ============================================================================
# Arch detection
# ============================================================================
# uname -m always returns x86_64 in MSYS2 (msys2-runtime#171).
# PROCESSOR_ARCHITECTURE also lies — reports AMD64 for x64 bash processes
# even on ARM64 hardware (MSYS2-packages#4960).
# $MSYSTEM is the canonical detection method used by MSYS2 itself.
step "Arch detection"

case "$MSYSTEM" in
    CLANGARM64)
        PKG_PREFIX="mingw-w64-clang-aarch64"
        MINGW_WIN_DIR="clangarm64"
        ;;
    MINGW64|UCRT64|*)
        PKG_PREFIX="mingw-w64-x86_64"
        MINGW_WIN_DIR="mingw64"
        ;;
esac

info "MSYSTEM=$MSYSTEM → PKG_PREFIX=${PKG_PREFIX}-"

echo ""
echo "${RED}This will undo everything bootstrap.sh installed.${NC}"
echo "MSYS2 base + git will remain. ~/.config/ will NOT be deleted."
echo ""
read -r -p "Continue? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

# ============================================================================
# 1. Windows user environment variables
# ============================================================================
step "1. Remove Windows user env vars"

MANAGED_USER_VARS=(MSYS MSYSTEM MSYS2_PATH_TYPE XDG_CONFIG_HOME CLAUDE_CODE_GIT_BASH_PATH)
for var in "${MANAGED_USER_VARS[@]}"; do
    powershell.exe -Command "[System.Environment]::SetEnvironmentVariable('$var', \$null, 'User')" 2>/dev/null
    info "Removed: $var"
done

# ============================================================================
# 2. Windows system PATH entries
# ============================================================================
step "2. Remove managed system PATH entries"

MANAGED_PATH_ENTRIES=(
    'C:\\msys64\\usr\\bin'
    'C:\\msys64\\mingw64\\bin'
    'C:\\msys64\\clangarm64\\bin'
    "$WIN_HOME\\.local\\bin"
)
for entry in "${MANAGED_PATH_ENTRIES[@]}"; do
    powershell.exe -Command "
        \$path = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
        \$entries = \$path -split ';' | Where-Object { \$_ -ne '$entry' -and \$_ -ne '' }
        [System.Environment]::SetEnvironmentVariable('PATH', (\$entries -join ';'), 'Machine')
    " 2>/dev/null
    info "Removed from PATH: $entry"
done

# ============================================================================
# 3. MSYS2 packages (keep git, base)
# ============================================================================
step "3. Remove MSYS2 packages"

# Remove stale lock from interrupted pacman runs
if [[ -f /var/lib/pacman/db.lck ]]; then
    rm -f /var/lib/pacman/db.lck
    warn "Removed stale pacman lock file"
fi

PACMAN_PKGS=(
    zsh
    "${PKG_PREFIX}-git-lfs"
    "${PKG_PREFIX}-go"
    "${PKG_PREFIX}-nodejs"
    "${PKG_PREFIX}-eza"
    "${PKG_PREFIX}-fzf"
    "${PKG_PREFIX}-bat"
    "${PKG_PREFIX}-gcc"
    "${PKG_PREFIX}-python"
    "${PKG_PREFIX}-python-pip"
    "${PKG_PREFIX}-python-pipx"
    "${PKG_PREFIX}-fd"
    "${PKG_PREFIX}-ripgrep"
)

# Remove all at once to avoid dependency ordering issues
INSTALLED=()
for pkg in "${PACMAN_PKGS[@]}"; do
    pacman -Q "$pkg" &>/dev/null && INSTALLED+=("$pkg")
done
if [[ ${#INSTALLED[@]} -gt 0 ]]; then
    pacman -Rns --noconfirm "${INSTALLED[@]}" 2>/dev/null || \
        pacman -Rd --noconfirm "${INSTALLED[@]}" 2>/dev/null || \
        warn "Some packages failed to remove"
    info "Removed: ${INSTALLED[*]}"
else
    info "No managed packages installed"
fi

# ============================================================================
# 4. Claude Code (npm global)
# ============================================================================
step "4. Remove Claude Code"

if command -v claude &>/dev/null; then
    npm uninstall -g @anthropic-ai/claude-code 2>/dev/null
    info "Uninstalled Claude Code"
else
    info "Claude Code not installed, skipping"
fi

# ============================================================================
# 5. cmake-language-server (pipx)
# ============================================================================
step "5. Remove cmake-language-server"

if command -v cmake-language-server &>/dev/null; then
    pipx uninstall cmake-language-server 2>/dev/null || warn "pipx uninstall failed"
    info "Uninstalled cmake-language-server"
else
    info "cmake-language-server not installed, skipping"
fi

# ============================================================================
# 6. Standalone tools (~/.local/bin)
# ============================================================================
step "6. Remove standalone tools and symlinks"

rm -f "$WINDOWS_HOME/.local/bin/oh-my-posh.exe" && info "Removed oh-my-posh"
rm -f "$WINDOWS_HOME/.local/bin/zoxide.exe" && info "Removed zoxide"
rm -f "$WINDOWS_HOME/.local/bin/bun" "$WINDOWS_HOME/.local/bin/bun.exe" && info "Removed bun symlinks"
rm -f "$WINDOWS_HOME/.local/bin/carol" && info "Removed carol symlink"

# ============================================================================
# 7. bun
# ============================================================================
step "7. Remove bun"

rm -rf "$WINDOWS_HOME/.bun" && info "Removed ~/.bun"

# ============================================================================
# 8. zsh-syntax-highlighting
# ============================================================================
step "8. Remove zsh-syntax-highlighting"

rm -rf /usr/share/zsh-syntax-highlighting && info "Removed zsh-syntax-highlighting"

# ============================================================================
# 9. Carol
# ============================================================================
step "9. Remove carol"

rm -rf "$WINDOWS_HOME/.carol" && info "Removed ~/.carol"

# ============================================================================
# 10. zsh dotfile symlinks
# ============================================================================
step "10. Remove zsh dotfile symlinks"

rm -f "$WINDOWS_HOME/.zshrc" && info "Removed ~/.zshrc symlink"
rm -f "$WINDOWS_HOME/.zprofile" && info "Removed ~/.zprofile symlink"

# ============================================================================
# 11. nvim data (lazy plugins, Mason tools, state)
# ============================================================================
step "11. Remove nvim data"

rm -rf "$WINDOWS_HOME/AppData/Local/nvim-data" && info "Removed nvim-data"
rm -rf "$WINDOWS_HOME/.local/share/nvim" && info "Removed ~/.local/share/nvim"
rm -rf "$WINDOWS_HOME/.local/state/nvim" && info "Removed ~/.local/state/nvim"
rm -rf "$WINDOWS_HOME/.cache/nvim" && info "Removed ~/.cache/nvim"

# ============================================================================
# 12. MSYS2 ini files (restore defaults)
# ============================================================================
step "12. Restore MSYS2 ini defaults"

ARCH_INI="/c/msys64/${MSYSTEM,,}.ini"
if [[ -f "$ARCH_INI" ]]; then
    sed -i 's/^MSYS=winsymlinks:nativestrict/#MSYS=winsymlinks:nativestrict/' "$ARCH_INI"
    info "Commented out winsymlinks in ${MSYSTEM,,}.ini"
fi

MSYS2_INI="/c/msys64/msys2.ini"
if [[ -f "$MSYS2_INI" ]]; then
    sed -i 's/^MSYS=winsymlinks:nativestrict/#MSYS=winsymlinks:nativestrict/' "$MSYS2_INI"
    sed -i 's/^MSYS2_PATH_TYPE=inherit/#MSYS2_PATH_TYPE=inherit/' "$MSYS2_INI"
    info "Commented out winsymlinks and PATH_TYPE in msys2.ini"
fi

# ============================================================================
# 13. nsswitch.conf (restore default home)
# ============================================================================
step "13. Restore MSYS2 home directory"

NSSWITCH="/etc/nsswitch.conf"
if grep -q "db_home: windows" "$NSSWITCH" 2>/dev/null; then
    sed -i 's/^db_home: windows/db_home: cygwin/' "$NSSWITCH"
    info "Restored db_home: cygwin (MSYS2 default)"
fi

# ============================================================================
# Summary
# ============================================================================
step "Teardown complete"

cat << SUMMARY

Machine is back to blank MSYS2 + git.

What remains:
  ~/.config/          (your config repo — untouched)
  MSYS2 base          (pacman, bash, core utils)
  git                 (MSYS2 git package)

To re-setup:
  bash ~/.config/bootstrap.sh

Note: Restart MSYS2 for ini/nsswitch changes to take effect.
After restart, ~ will be /home/<user> again (not Windows home).
Use: cd /c/Users/<user>/.config to reach config repo.

SUMMARY
