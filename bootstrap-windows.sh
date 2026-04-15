#!/bin/bash
# ============================================================================
# bootstrap-windows.sh — Windows dev environment setup (MSYS2/zsh)
# ============================================================================
# Prerequisite: MSYS2 installed at C:\msys64
#
# Run from MSYS2 MinGW64 or CLANGARM64 shell as Administrator:
#   bash ~/.config/bootstrap.sh
#
# Supports x64 (MINGW64) and ARM64 (CLANGARM64).
# Architecture is auto-detected via PROCESSOR_ARCHITECTURE — uname -m is
# unreliable on ARM64 Windows (MINGW64 always reports x86_64 via emulation).
# ============================================================================
set -e

# Ensure native symlinks are used in THIS session, not just after restart.
# Without this, ln -sf silently creates file copies on Windows/MSYS2.
export MSYS=winsymlinks:nativestrict

# Colors — use $'...' so echo doesn't need -e (which mangles \b in paths)
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
info "Windows home: $WINDOWS_HOME"

# ============================================================================
# Arch detection
# ============================================================================
# uname -m always returns x86_64 in MSYS2 — the runtime is an x64 binary
# running under Windows x64 emulation, even on ARM64 hardware (msys2-runtime#171).
# PROCESSOR_ARCHITECTURE is also wrong: Windows reports AMD64 for x64 processes
# even on ARM64 hosts (MSYS2-packages#4960).
#
# $MSYSTEM is the canonical method: MSYS2 and Git-for-Windows both use it.
# Users launching CLANGARM64 terminal get MSYSTEM=CLANGARM64.
# Users launching MINGW64 terminal get MSYSTEM=MINGW64.
#
# uname -s carries a -ARM64 suffix on ARM64 hardware (msys2-runtime PR#244),
# which lets us warn users who are on ARM64 but launched the wrong shell.
step "Arch detection"

case "$MSYSTEM" in
    CLANGARM64)
        PKG_PREFIX="mingw-w64-clang-aarch64"
        MINGW_DIR="/clangarm64"
        MINGW_WIN_DIR="clangarm64"
        BUN_ARCH="windows-aarch64"
        OMP_ARCH="arm64"
        ZOXIDE_PATTERN="aarch64-pc-windows-msvc"
        WHATDBG_ASSET="whatdbg-win-arm64"
        ;;
    MINGW64|UCRT64|*)
        PKG_PREFIX="mingw-w64-x86_64"
        MINGW_DIR="/mingw64"
        MINGW_WIN_DIR="mingw64"
        BUN_ARCH="windows-x64"
        OMP_ARCH="amd64"
        ZOXIDE_PATTERN="x86_64-pc-windows-msvc"
        WHATDBG_ASSET="whatdbg-win-x64"
        ;;
esac

info "MSYSTEM=$MSYSTEM → PKG_PREFIX=${PKG_PREFIX}-"

# Warn if user is on ARM64 hardware but launched the wrong shell
if [[ "$(uname -s)" == *"-ARM64"* && "$MSYSTEM" != "CLANGARM64" ]]; then
    warn "ARM64 hardware detected (uname -s: $(uname -s)) but MSYSTEM=$MSYSTEM"
    warn "For native ARM64 performance, relaunch using the CLANGARM64 terminal shortcut."
fi

# ============================================================================
# 0. Reset — clear all env vars this script manages so they're always set fresh
# ============================================================================
step "0. Reset previous environment"

# User env vars managed by this script
MANAGED_USER_VARS=(MSYS MSYSTEM MSYS2_PATH_TYPE XDG_CONFIG_HOME CLAUDE_CODE_GIT_BASH_PATH)
for var in "${MANAGED_USER_VARS[@]}"; do
    powershell.exe -Command "[System.Environment]::SetEnvironmentVariable('$var', \$null, 'User')" 2>/dev/null
done
info "Cleared user env vars: ${MANAGED_USER_VARS[*]}"

# System PATH entries managed by this script — remove stale/corrupted entries.
# Remove both possible arch paths so a machine that switched environments is clean.
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
done
info "Cleaned managed entries from system PATH"

# ============================================================================
# 1. MSYS2 home → Windows home
# ============================================================================
step "1. MSYS2 home directory"

NSSWITCH="/etc/nsswitch.conf"
if grep -q "db_home: windows" "$NSSWITCH" 2>/dev/null; then
    info "Already set: db_home: windows"
else
    warn "Setting db_home: windows in $NSSWITCH"
    if grep -q "db_home:" "$NSSWITCH"; then
        sed -i 's/^db_home:.*/db_home: windows/' "$NSSWITCH"
    else
        echo "db_home: windows" >> "$NSSWITCH"
    fi
    info "Done. Restart MSYS2 for this to take effect."
fi

# ============================================================================
# 2. MSYS2 ini files
# ============================================================================
step "2. MSYS2 ini files"

# Arch-specific ini (mingw64.ini or clangarm64.ini) — native symlinks
ARCH_INI="/c/msys64/${MSYSTEM,,}.ini"
if grep -q "^MSYS=winsymlinks:nativestrict" "$ARCH_INI" 2>/dev/null; then
    info "Already set: MSYS=winsymlinks:nativestrict in ${MSYSTEM,,}.ini"
else
    if grep -q "winsymlinks" "$ARCH_INI" 2>/dev/null; then
        sed -i 's/^#*MSYS=winsymlinks.*/MSYS=winsymlinks:nativestrict/' "$ARCH_INI"
    else
        echo "MSYS=winsymlinks:nativestrict" >> "$ARCH_INI"
    fi
    info "Set MSYS=winsymlinks:nativestrict in ${MSYSTEM,,}.ini"
fi

# msys2.ini — default environment, path inheritance, and symlinks
MSYS2_INI="/c/msys64/msys2.ini"
sed -i 's/^#*MSYS=winsymlinks.*/MSYS=winsymlinks:nativestrict/' "$MSYS2_INI"
sed -i 's/^#*MSYS2_PATH_TYPE=.*/MSYS2_PATH_TYPE=inherit/' "$MSYS2_INI"
if grep -q "^MSYSTEM=" "$MSYS2_INI"; then
    sed -i "s/^MSYSTEM=.*/MSYSTEM=${MSYSTEM}/" "$MSYS2_INI"
else
    echo "MSYSTEM=${MSYSTEM}" >> "$MSYS2_INI"
fi
info "Updated msys2.ini: MSYSTEM=$MSYSTEM, MSYS2_PATH_TYPE=inherit, winsymlinks:nativestrict"

# ============================================================================
# 3. Windows user environment variables
# ============================================================================
step "3. Windows environment variables"

set_win_env() {
    local name="$1" value="$2"
    local current
    current=$(powershell.exe -Command "[System.Environment]::GetEnvironmentVariable('$name', 'User')" 2>/dev/null | tr -d '\r')
    if [[ "$current" == "$value" ]]; then
        info "Already set: $name=$value"
    else
        powershell.exe -Command "[System.Environment]::SetEnvironmentVariable('$name', '$value', 'User')" 2>/dev/null
        info "Set: $name=$value"
    fi
}

set_win_env "MSYS" "winsymlinks:nativestrict"
set_win_env "MSYSTEM" "$MSYSTEM"
set_win_env "MSYS2_PATH_TYPE" "inherit"
set_win_env "XDG_CONFIG_HOME" "$WIN_HOME\\.config"
set_win_env "CLAUDE_CODE_GIT_BASH_PATH" "C:\\msys64\\usr\\bin\\bash.exe"

add_to_system_path() {
    local entry="$1"
    local current
    current=$(powershell.exe -Command "[System.Environment]::GetEnvironmentVariable('PATH', 'Machine')" | tr -d '\r')
    if echo "$current" | grep -qi "$(echo "$entry" | sed 's/\\/\\\\/g')"; then
        info "Already in system PATH: $entry"
    else
        powershell.exe -Command "[System.Environment]::SetEnvironmentVariable('PATH', '$entry;' + [System.Environment]::GetEnvironmentVariable('PATH', 'Machine'), 'Machine')"
        info "Added to system PATH: $entry"
    fi
}

add_to_system_path "C:\\msys64\\usr\\bin"
add_to_system_path "C:\\msys64\\${MINGW_WIN_DIR}\\bin"
add_to_system_path "$WIN_HOME\\.local\\bin"

# ============================================================================
# 4. Install MSYS2 packages
# ============================================================================
step "4. MSYS2 packages"

# Remove stale lock from interrupted pacman runs
if [[ -f /var/lib/pacman/db.lck ]]; then
    rm -f /var/lib/pacman/db.lck
    warn "Removed stale pacman lock file"
fi

PACMAN_PKGS=(
    zsh
    git
    unzip
    "${PKG_PREFIX}-git-lfs"
    "${PKG_PREFIX}-go"
    "${PKG_PREFIX}-nodejs"
    "${PKG_PREFIX}-eza"
    "${PKG_PREFIX}-fzf"
    "${PKG_PREFIX}-bat"
    "${PKG_PREFIX}-gcc"
    "${PKG_PREFIX}-python"
    "${PKG_PREFIX}-python-pip"   # required by pipx
    "${PKG_PREFIX}-python-pipx"  # Mason uses pipx to install cmake-language-server
    "${PKG_PREFIX}-fd"           # snacks.nvim file finder (find is disabled on Windows by snacks)
    "${PKG_PREFIX}-ripgrep"      # snacks.nvim grep search (<leader>fg)
    "${PKG_PREFIX}-jq"           # JSON processor (used by carol for settings.json merge)
)

for pkg in "${PACMAN_PKGS[@]}"; do
    if pacman -Q "$pkg" &>/dev/null; then
        info "Already installed: $pkg"
    else
        warn "Installing: $pkg"
        pacman -S --noconfirm "$pkg"
    fi
done

# ============================================================================
# 4b. bun (not in MSYS2 repos)
# ============================================================================
step "4b. bun"

BUN_DIR="$WINDOWS_HOME/.bun/bin"
mkdir -p "$BUN_DIR"

if [[ -f "$BUN_DIR/bun.exe" ]]; then
    info "bun already installed"
else
    warn "Downloading bun ($BUN_ARCH)..."
    BUN_URL=$(curl -fsSL "https://api.github.com/repos/oven-sh/bun/releases/latest" \
        | grep "browser_download_url.*bun-${BUN_ARCH}\.zip" | head -1 | cut -d '"' -f 4)
    if [[ -n "$BUN_URL" ]]; then
        curl -fsSL "$BUN_URL" -o /tmp/bun.zip
        unzip -o /tmp/bun.zip "bun-${BUN_ARCH}/bun.exe" -d /tmp/bun-extract/
        mv /tmp/bun-extract/bun-${BUN_ARCH}/bun.exe "$BUN_DIR/bun.exe"
        rm -rf /tmp/bun.zip /tmp/bun-extract
        info "bun installed to $BUN_DIR"
    else
        error "Failed to find bun release URL for $BUN_ARCH"
    fi
fi

# ============================================================================
# 4c. zsh-syntax-highlighting (not in MSYS2 repos)
# ============================================================================
step "4c. zsh-syntax-highlighting"

ZSH_HL_DIR="/usr/share/zsh-syntax-highlighting"
if [[ -d "$ZSH_HL_DIR/.git" ]]; then
    info "zsh-syntax-highlighting already cloned"
else
    warn "Cloning zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_HL_DIR"
    info "zsh-syntax-highlighting cloned"
fi

# ============================================================================
# 4d. cmake-language-server (via pipx, not Mason)
# ============================================================================
# Mason's cmake-language-server package requires python <3.14, but MSYS2 ships
# python 3.14+. pipx installs into its own isolated venv, bypassing the check.
# Binary lands at ~/.local/bin/cmake-language-server (already in PATH).
step "4d. cmake-language-server"

if command -v cmake-language-server &>/dev/null; then
    info "cmake-language-server already installed: $(cmake-language-server --version 2>&1 | head -1)"
else
    warn "Installing cmake-language-server via pipx..."
    pipx install cmake-language-server
    info "cmake-language-server installed"
fi

# ============================================================================
# 4e. goreleaser (via go install — not in MSYS2 repos)
# ============================================================================
step "4e. goreleaser"

if command -v goreleaser &>/dev/null; then
    info "goreleaser already installed"
else
    warn "Installing goreleaser via go install..."
    GOBIN="$WINDOWS_HOME/.local/bin" go install github.com/goreleaser/goreleaser/v2@latest
    info "goreleaser installed"
fi

# ============================================================================
# 5. Download standalone tools (oh-my-posh, zoxide)
# ============================================================================
step "5. Standalone tools"

mkdir -p "$WINDOWS_HOME/.local/bin"

# oh-my-posh
if [[ -f "$WINDOWS_HOME/.local/bin/oh-my-posh.exe" ]]; then
    info "oh-my-posh already installed"
else
    warn "Downloading oh-my-posh ($OMP_ARCH)..."
    curl -fsSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-${OMP_ARCH}.exe" \
        -o "$WINDOWS_HOME/.local/bin/oh-my-posh.exe"
    info "oh-my-posh installed"
fi

# whatdbg (DAP adapter — dbgeng-based, reads PDB natively)
if [[ -f "$WINDOWS_HOME/.local/bin/whatdbg.exe" ]]; then
    info "whatdbg already installed"
else
    warn "Downloading whatdbg ($WHATDBG_ASSET)..."
    WHATDBG_URL=$(curl -fsSL "https://api.github.com/repos/jrengmusic/whatdbg/releases/latest" \
        | grep "browser_download_url.*${WHATDBG_ASSET}\.zip" | head -1 | cut -d '"' -f 4)
    if [[ -n "$WHATDBG_URL" ]]; then
        curl -fsSL "$WHATDBG_URL" -o /tmp/whatdbg.zip
        unzip -o /tmp/whatdbg.zip whatdbg.exe -d "$WINDOWS_HOME/.local/bin/"
        rm -f /tmp/whatdbg.zip
        info "whatdbg installed"
    else
        error "Failed to find whatdbg release URL"
    fi
fi

# zoxide
if [[ -f "$WINDOWS_HOME/.local/bin/zoxide.exe" ]]; then
    info "zoxide already installed"
else
    warn "Downloading zoxide ($ZOXIDE_PATTERN)..."
    ZOXIDE_URL=$(curl -fsSL "https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest" \
        | grep "browser_download_url.*${ZOXIDE_PATTERN}\.zip" | head -1 | cut -d '"' -f 4)
    if [[ -n "$ZOXIDE_URL" ]]; then
        curl -fsSL "$ZOXIDE_URL" -o /tmp/zoxide.zip
        unzip -o /tmp/zoxide.zip zoxide.exe -d "$WINDOWS_HOME/.local/bin/"
        rm -f /tmp/zoxide.zip
        info "zoxide installed"
    else
        error "Failed to find zoxide release URL for $ZOXIDE_PATTERN"
    fi
fi

# ============================================================================
# 5b. ~/.local/bin symlinks
# ============================================================================
step "5b. ~/.local/bin symlinks"

# NOTE: Do NOT symlink MSYS2-native tools (zsh, python, node, go, bat, eza,
# fzf, gcc, git-lfs, npm) into ~/.local/bin.
#
# Reason: /usr/bin and ${MINGW_DIR}/bin are already in PATH (added above).
# Many MSYS2 binaries (especially python.exe) are small launcher stubs that
# depend on DLLs in their source directory. Copying or symlinking them into
# ~/.local/bin causes DLL load failures (e.g. "ImportError: cannot import zlib")
# because the binary runs from a different directory context.
#
# Only symlink tools whose source directory is NOT in PATH:
#   - bun  (~/.bun/bin)
#   - carol (~/.carol/bin)

link_bin() {
    local src="$1" name="$2"
    local dst="$WINDOWS_HOME/.local/bin/$name"
    if [[ ! -f "$src" ]]; then
        warn "Skipping symlink for $name: source not found at $src"
        return
    fi
    # Symlink without extension (for zsh/bash)
    # Remove stale regular-file copies that ln -sf would silently produce
    # when MSYS=winsymlinks:nativestrict was not active in a previous run.
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        info "Already symlinked: $name"
    else
        [[ -e "$dst" && ! -L "$dst" ]] && rm -f "$dst"
        ln -sf "$src" "$dst"
        info "Symlinked: $name → $src"
    fi
    # Symlink with .exe extension (for Windows-native callers)
    if [[ "$src" == *.exe ]]; then
        local dst_exe="$WINDOWS_HOME/.local/bin/$name.exe"
        if [[ -L "$dst_exe" && "$(readlink "$dst_exe")" == "$src" ]]; then
            info "Already symlinked: $name.exe"
        else
            [[ -e "$dst_exe" && ! -L "$dst_exe" ]] && rm -f "$dst_exe"
            ln -sf "$src" "$dst_exe"
            info "Symlinked: $name.exe → $src"
        fi
    fi
}

# bun (~/.bun/bin is not in PATH)
link_bin "$WINDOWS_HOME/.bun/bin/bun.exe" "bun"

# ============================================================================
# 6. zsh dotfile symlinks
# ============================================================================
step "6. zsh dotfile symlinks"

link_dotfile() {
    local src="$1" dst="$2"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        info "Already symlinked: $dst → $src"
    else
        # Use -e (not -f) to also catch stale copies that are dirs/junctions
        [[ -e "$dst" && ! -L "$dst" ]] && rm -f "$dst"
        ln -sf "$src" "$dst"
        info "Symlinked: $dst → $src"
    fi
}

link_dotfile "$WINDOWS_HOME/.config/zsh/zshrc"   "$WINDOWS_HOME/.zshrc"
link_dotfile "$WINDOWS_HOME/.config/zsh/zprofile" "$WINDOWS_HOME/.zprofile"

# ============================================================================
# 8. Neovim config
# ============================================================================
step "8. Neovim config"

# With XDG_CONFIG_HOME set, nvim reads ~/.config/nvim directly — no symlink needed.
info "XDG_CONFIG_HOME is set → nvim uses ~/.config/nvim directly"

# ============================================================================
# 9. Neovim — Mason LSP/DAP tools
# ============================================================================
step "9. Neovim Mason tools"

echo "After launching nvim, Mason will auto-install all LSP servers."
echo ""
echo "Notes:"
echo "  - Do NOT install clangd via Mason (it's a .cmd wrapper, won't work)"
echo "  - System clangd from LLVM.LLVM is used automatically"
echo "  - Do NOT install cmake-language-server via Mason (requires python <3.14,"
echo "    but MSYS2 ships 3.14+). It was installed via pipx in step 4d instead."
echo "  - DAP adapter: codelldb on macOS, whatdbg on Windows"
echo "  - whatdbg reads PDB symbols via dbgeng.dll (supports DAW plugin attach)"

# ============================================================================
# 10. Carol (carolcode wrapper)
# ============================================================================
step "10. Carol"

if [[ -d "$WINDOWS_HOME/.carol" ]]; then
    info "~/.carol already exists"
else
    warn "Cloning carol..."
    git clone git@github.com:jrengmusic/carol.git "$WINDOWS_HOME/.carol"
    info "Cloned carol to ~/.carol"
fi

CAROL_LINK="$WINDOWS_HOME/.local/bin/carol"
CAROL_TARGET="$WINDOWS_HOME/.carol/bin/carol"
if [[ -L "$CAROL_LINK" && "$(readlink "$CAROL_LINK")" == "$CAROL_TARGET" ]]; then
    info "carol symlink already correct"
else
    # Remove stale regular-file copy before symlinking (same fix as link_bin)
    [[ -e "$CAROL_LINK" && ! -L "$CAROL_LINK" ]] && rm -f "$CAROL_LINK"
    ln -sf "$CAROL_TARGET" "$CAROL_LINK"
    info "Symlinked carol → $CAROL_TARGET"
fi

# ============================================================================
# 11. Claude Code (via npm — native installer does not work on Windows/MSYS2)
# ============================================================================
step "11. Claude Code"

if command -v claude &>/dev/null; then
    info "claude already installed: $(which claude)"
else
    # Stub ~/.zshrc at MSYS2 home so npm's postinstall zsh shell does not
    # trigger the new-user wizard. ~ is still /home/<user> here — nsswitch
    # change (db_home: windows) requires a restart to take effect.
    [[ ! -f "$HOME/.zshrc" ]] && touch "$HOME/.zshrc"
    info "Installing Claude Code via npm..."
    npm install -g @anthropic-ai/claude-code
    info "Note: npm may warn about native installation — ignore it, npm is the only working method on Windows/MSYS2"
fi

# Global CLAUDE.md — symlink from config repo to ~/.claude/
mkdir -p "$WINDOWS_HOME/.claude"
CLAUDE_MD_SRC="$WINDOWS_HOME/.config/claude/CLAUDE.md"
CLAUDE_MD_DST="$WINDOWS_HOME/.claude/CLAUDE.md"
if [[ -L "$CLAUDE_MD_DST" && "$(readlink "$CLAUDE_MD_DST")" == "$CLAUDE_MD_SRC" ]]; then
    info "CLAUDE.md symlink already correct"
else
    [[ -e "$CLAUDE_MD_DST" && ! -L "$CLAUDE_MD_DST" ]] && rm -f "$CLAUDE_MD_DST"
    ln -sf "$CLAUDE_MD_SRC" "$CLAUDE_MD_DST"
    info "Symlinked CLAUDE.md → $CLAUDE_MD_SRC"
fi

# Project CLAUDE.md — symlink CAROL.md as project-level instructions
CAROL_MD_SRC="$WINDOWS_HOME/.carol/CAROL.md"
CAROL_MD_DST="$WINDOWS_HOME/.config/CLAUDE.md"
if [[ -L "$CAROL_MD_DST" && "$(readlink "$CAROL_MD_DST")" == "$CAROL_MD_SRC" ]]; then
    info "Project CLAUDE.md symlink already correct"
else
    [[ -e "$CAROL_MD_DST" && ! -L "$CAROL_MD_DST" ]] && rm -f "$CAROL_MD_DST"
    ln -sf "$CAROL_MD_SRC" "$CAROL_MD_DST"
    info "Symlinked project CLAUDE.md → $CAROL_MD_SRC"
fi

# ============================================================================
# 12. Windows software (manual steps)
# ============================================================================
step "12. Manual installs (winget / installers)"

cat << 'EOF'
The following should be installed via winget or manually:

  winget install Neovim.Neovim
  winget install LLVM.LLVM            # clangd (LSP)
  winget install GoLang.Go
  winget install oven-sh.Bun
  winget install Git.Git
  winget install aristocratos.btop4win    # x64-only, runs under emulation on ARM64
  winget install Microsoft.VisualStudio.2022.Community
    (with "Desktop development with C++" workload)

LLVM provides:
  - clangd: LSP server (Mason's clangd is .cmd on Windows, won't work)

Visual Studio provides:
  - cl.exe: MSVC compiler (produces PDB debug symbols)
  - vcvarsall.bat: sets up MSVC compiler, linker, headers, and libs
  - cmake + ninja: bundled with VS, used by build.bat
  - JUCE rejects MinGW, so MSVC environment is required

The build pipeline uses: cl.exe (compiler) + MSVC (linker/headers) + Ninja
Debug symbols are PDB format, read by whatdbg (dbgeng.dll DAP adapter).
EOF

# ============================================================================
# 13. END terminal (optional)
# ============================================================================
step "13. END terminal"

if [[ -f "$WINDOWS_HOME/.local/bin/END.exe" ]]; then
    info "END.exe found in ~/.local/bin"
else
    warn "END.exe not found. Copy it to ~/.local/bin/END.exe"
fi

echo ""
echo "END terminal config is at ~/.config/end/end.lua"
echo "Set program to launch zsh with --login for proper MSYS2 env."

# ============================================================================
# Summary
# ============================================================================
step "Setup complete"

cat << EOF

Restart MSYS2 / END terminal for all changes to take effect.
Launch using the ${MSYSTEM} terminal shortcut for native toolchain.

Key paths:
  Config repo:    ~/.config/
  nvim config:    ~/AppData/Local/nvim → ~/.config/nvim
  Build scripts:  ~/.config/nvim/scripts/build-debug.bat (Windows)
                  ~/.config/nvim/scripts/clean-build.sh  (cross-platform)
  CLI tools:      ~/.local/bin/ (oh-my-posh, zoxide, carol, END)
  Carol:          ~/.carol/bin/carol
  Claude Code:    npm global (@anthropic-ai/claude-code)
  MSYS2 toolchain: ${MINGW_DIR}/bin/

nvim keybindings:
  <leader>bk  Clean build directory
  <leader>bb  Build only
  <leader>bc  Clean + build
  <leader>br  Build + run (launch DAW + attach DAP)
  <F5>        Configure DAP (select format/DAW/scheme)

EOF

# Reload shell so new env vars take effect immediately
exec zsh
