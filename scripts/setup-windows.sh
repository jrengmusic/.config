#!/bin/bash
# ============================================================================
# setup-windows.sh — Windows dev environment setup (MSYS2/zsh)
# ============================================================================
# Prerequisite: MSYS2 installed at C:\msys64
#
# Run from MSYS2 MinGW64 shell:
#   bash ~/.config/scripts/setup-windows.sh
#
# This script replicates the macOS dev environment on Windows:
#   - MSYS2 home → Windows home
#   - zsh as default shell with oh-my-posh
#   - nvim with symlink, LSP, DAP, treesitter
#   - CLI tools: eza, fzf, bat, zoxide
#   - carolcode + opencode (separate installs)
#   - JUCE build pipeline (MSVC + CMake + Ninja)
# ============================================================================
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $1"; }
error() { echo -e "${RED}[ERR]${NC} $1"; }
step()  { echo -e "\n${GREEN}━━━ $1 ━━━${NC}"; }

# ============================================================================
# Preflight checks
# ============================================================================
step "Preflight checks"

if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" ]]; then
    error "This script must be run from MSYS2. Exiting."
    exit 1
fi

if [[ "$MSYSTEM" != "MINGW64" ]]; then
    warn "MSYSTEM is '$MSYSTEM', expected 'MINGW64'. Some packages may not install correctly."
fi

WINDOWS_HOME="/c/Users/$(whoami)"
if [[ ! -d "$WINDOWS_HOME" ]]; then
    error "Windows home not found at $WINDOWS_HOME"
    exit 1
fi
info "Windows home: $WINDOWS_HOME"

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
# 2. mingw64.ini — native symlinks
# ============================================================================
step "2. MSYS2 native symlinks"

MINGW_INI="/c/msys64/mingw64.ini"
if grep -q "^MSYS=winsymlinks:nativestrict" "$MINGW_INI" 2>/dev/null; then
    info "Already set: MSYS=winsymlinks:nativestrict"
else
    # Uncomment or add the line
    if grep -q "winsymlinks" "$MINGW_INI" 2>/dev/null; then
        sed -i 's/^#*MSYS=winsymlinks.*/MSYS=winsymlinks:nativestrict/' "$MINGW_INI"
    else
        echo "MSYS=winsymlinks:nativestrict" >> "$MINGW_INI"
    fi
    info "Set MSYS=winsymlinks:nativestrict in mingw64.ini"
fi

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
set_win_env "MSYSTEM" "MINGW64"
set_win_env "MSYS2_PATH_TYPE" "inherit"

# ============================================================================
# 4. Install MSYS2 packages
# ============================================================================
step "4. MSYS2 packages"

PACMAN_PKGS=(
    zsh
    mingw-w64-x86_64-eza
    mingw-w64-x86_64-fzf
    mingw-w64-x86_64-bat
    mingw-w64-x86_64-gcc
    mingw-w64-x86_64-ninja
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
# 5. ~/.local/bin tools (oh-my-posh, zoxide)
# ============================================================================
step "5. CLI tools in ~/.local/bin"

mkdir -p "$HOME/.local/bin"

# oh-my-posh
if [[ -f "$HOME/.local/bin/oh-my-posh.exe" ]]; then
    info "oh-my-posh already installed"
else
    warn "Downloading oh-my-posh..."
    curl -fsSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-amd64.exe" \
        -o "$HOME/.local/bin/oh-my-posh.exe"
    info "oh-my-posh installed"
fi

# zoxide
if [[ -f "$HOME/.local/bin/zoxide.exe" ]]; then
    info "zoxide already installed"
else
    warn "Downloading zoxide..."
    ZOXIDE_URL=$(curl -fsSL "https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest" \
        | grep "browser_download_url.*x86_64-pc-windows-msvc.zip" | head -1 | cut -d '"' -f 4)
    if [[ -n "$ZOXIDE_URL" ]]; then
        curl -fsSL "$ZOXIDE_URL" -o /tmp/zoxide.zip
        unzip -o /tmp/zoxide.zip zoxide.exe -d "$HOME/.local/bin/"
        rm -f /tmp/zoxide.zip
        info "zoxide installed"
    else
        error "Failed to find zoxide release URL"
    fi
fi

# ============================================================================
# 6. Clone config repo
# ============================================================================
step "6. Config repo"

if [[ -d "$HOME/.config/.git" ]]; then
    info "Config repo already cloned at ~/.config"
else
    warn "Cloning config repo..."
    git clone git@github.com:jrengmusic/.config.git "$HOME/.config"
    info "Config repo cloned"
fi

# ============================================================================
# 7. Bootstrap ~/.zshrc
# ============================================================================
step "7. Bootstrap ~/.zshrc"

ZSHRC="$HOME/.zshrc"
if [[ -f "$ZSHRC" ]] && grep -q "zsh/zprofile" "$ZSHRC"; then
    info "~/.zshrc already configured"
else
    cat > "$ZSHRC" << 'EOF'
# Created by setup-windows.sh

# Source shared config from repo
[ -f ~/.config/zsh/zprofile ] && source ~/.config/zsh/zprofile
[ -f ~/.config/zsh/zshrc ] && source ~/.config/zsh/zshrc
EOF
    info "Created ~/.zshrc"
fi

# ============================================================================
# 8. Neovim symlink
# ============================================================================
step "8. Neovim config symlink"

NVIM_CONFIG="$HOME/AppData/Local/nvim"
if [[ -L "$NVIM_CONFIG" ]]; then
    info "nvim symlink already exists: $(readlink "$NVIM_CONFIG")"
elif [[ -d "$NVIM_CONFIG" ]]; then
    warn "$NVIM_CONFIG exists as a directory. Back it up and re-run."
else
    ln -s "$HOME/.config/nvim" "$NVIM_CONFIG"
    info "Created symlink: $NVIM_CONFIG → ~/.config/nvim"
fi

# ============================================================================
# 9. Neovim — Mason LSP/DAP tools
# ============================================================================
step "9. Neovim Mason tools"

echo "After launching nvim, run:"
echo "  :MasonInstall lua_ls pyright ts_ls zls stylua prettier codelldb"
echo ""
echo "Notes:"
echo "  - Do NOT install clangd via Mason (it's a .cmd wrapper, won't work)"
echo "  - System clangd from LLVM.LLVM is used automatically"
echo "  - codelldb is the DAP adapter for both macOS and Windows"
echo "  - On Windows, clang-cl produces DWARF symbols that codelldb reads"

# ============================================================================
# 10. Carol (carolcode wrapper)
# ============================================================================
step "10. Carol"

if [[ -d "$HOME/.carol" ]]; then
    info "~/.carol already exists"
else
    warn "Cloning carol..."
    git clone https://github.com/jrengmusic/carol.git "$HOME/.carol"
    info "Cloned carol to ~/.carol"
fi

if [[ -f "$HOME/.carol/bin/carolcode-x64.exe" ]]; then
    info "carolcode binary already in ~/.carol/bin"
else
    warn "carolcode binary not found in ~/.carol/bin"
    echo "Build from source:"
    echo "  cd ~/Documents/Poems/dev/carolcode"
    echo "  bun install"
    echo "  bun run packages/opencode/script/build.ts --single --skip-install"
    echo "  cp packages/opencode/dist/opencode-windows-x64/bin/carolcode-x64.exe ~/.carol/bin/"
fi

if [[ -L "$HOME/.local/bin/carol" ]]; then
    info "carol symlink already exists"
else
    ln -sf "$HOME/.carol/bin/carol" "$HOME/.local/bin/carol"
    info "Symlinked carol → ~/.local/bin/carol"
fi

# ============================================================================
# 11. Opencode (vanilla, via npm)
# ============================================================================
step "11. Opencode"

if command -v opencode &>/dev/null; then
    info "opencode already installed: $(which opencode)"
else
    warn "Install opencode via: npm install -g opencode"
fi

# ============================================================================
# 12. Windows software (manual steps)
# ============================================================================
step "12. Manual installs (winget / installers)"

cat << 'EOF'
The following should be installed via winget or manually:

  winget install Neovim.Neovim
  winget install LLVM.LLVM            # clang-cl (compiler) + clangd (LSP)
  winget install GoLang.Go
  winget install oven-sh.Bun
  winget install Git.Git
  winget install Microsoft.VisualStudio.2022.Community
    (with "Desktop development with C++" workload)

LLVM provides:
  - clang-cl: MSVC-compatible compiler that produces DWARF debug symbols
  - clangd: LSP server (Mason's clangd is .cmd on Windows, won't work)

Visual Studio provides:
  - vcvarsall.bat: sets up MSVC linker, headers, and libs
  - JUCE rejects MinGW, so MSVC environment is required even with clang-cl

The build pipeline uses: clang-cl (compiler) + MSVC (linker/headers) + Ninja
Debug symbols are DWARF format, read by codelldb/LLDB (same as macOS).
EOF

# ============================================================================
# 13. END terminal (optional)
# ============================================================================
step "13. END terminal"

if [[ -f "$HOME/.local/bin/END.exe" ]]; then
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

cat << 'EOF'

Restart MSYS2 / END terminal for all changes to take effect.

Key paths:
  Config repo:    ~/.config/
  nvim config:    ~/AppData/Local/nvim → ~/.config/nvim
  Build scripts:  ~/.config/nvim/scripts/build-debug.bat (Windows)
                  ~/.config/nvim/scripts/clean-build.sh  (cross-platform)
  CLI tools:      ~/.local/bin/ (oh-my-posh, zoxide, carol, END)
  Carol:          ~/.carol/bin/ (carolcode binary + carol script)
  Opencode:       npm global (separate from carol)

nvim keybindings:
  <leader>bk  Clean build directory
  <leader>bb  Build only
  <leader>bc  Clean + build
  <leader>br  Build + run (launch DAW + attach DAP)
  <F5>        Configure DAP (select format/DAW/scheme)

EOF
