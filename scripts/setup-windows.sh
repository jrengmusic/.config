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
#   - CLI tools: eza, fzf, bat, zoxide, bun
#   - Languages: go, node, npm (via nodejs), bun
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
WIN_HOME="C:\\Users\\$(whoami)"
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
# 2. MSYS2 ini files
# ============================================================================
step "2. MSYS2 ini files"

# mingw64.ini — native symlinks
MINGW_INI="/c/msys64/mingw64.ini"
if grep -q "^MSYS=winsymlinks:nativestrict" "$MINGW_INI" 2>/dev/null; then
    info "Already set: MSYS=winsymlinks:nativestrict in mingw64.ini"
else
    if grep -q "winsymlinks" "$MINGW_INI" 2>/dev/null; then
        sed -i 's/^#*MSYS=winsymlinks.*/MSYS=winsymlinks:nativestrict/' "$MINGW_INI"
    else
        echo "MSYS=winsymlinks:nativestrict" >> "$MINGW_INI"
    fi
    info "Set MSYS=winsymlinks:nativestrict in mingw64.ini"
fi

# msys2.ini — set MSYSTEM=MINGW64 and enable path inheritance and symlinks
MSYS2_INI="/c/msys64/msys2.ini"
sed -i 's/^#*MSYS=winsymlinks.*/MSYS=winsymlinks:nativestrict/' "$MSYS2_INI"
sed -i 's/^#*MSYS2_PATH_TYPE=.*/MSYS2_PATH_TYPE=inherit/' "$MSYS2_INI"
sed -i 's/^MSYSTEM=.*/MSYSTEM=MINGW64/' "$MSYS2_INI"
info "Updated msys2.ini: MSYSTEM=MINGW64, MSYS2_PATH_TYPE=inherit, winsymlinks:nativestrict"

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
set_win_env "XDG_CONFIG_HOME" "$WIN_HOME\\.config"

add_to_system_path() {
    local entry="$1"
    local current
    current=$(powershell.exe -Command "[System.Environment]::GetEnvironmentVariable('PATH', 'Machine')" 2>/dev/null | tr -d '\r')
    if echo "$current" | grep -qi "$(echo "$entry" | sed 's/\\/\\\\/g')"; then
        info "Already in system PATH: $entry"
    else
        powershell.exe -Command "[System.Environment]::SetEnvironmentVariable('PATH', '$entry;' + [System.Environment]::GetEnvironmentVariable('PATH', 'Machine'), 'Machine')" 2>/dev/null
        info "Added to system PATH: $entry"
    fi
}

add_to_system_path "C:\\msys64\\usr\\bin"
add_to_system_path "$WIN_HOME\\.local\\bin"

# ============================================================================
# 4. Install MSYS2 packages
# ============================================================================
step "4. MSYS2 packages"

PACMAN_PKGS=(
    zsh
    git
    unzip
    mingw-w64-x86_64-git-lfs
    mingw-w64-x86_64-cmake
    mingw-w64-x86_64-go
    mingw-w64-x86_64-nodejs
    mingw-w64-x86_64-eza
    mingw-w64-x86_64-fzf
    mingw-w64-x86_64-bat
    mingw-w64-x86_64-gcc
    mingw-w64-x86_64-ninja
    mingw-w64-x86_64-python
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
    warn "Downloading bun..."
    BUN_URL=$(curl -fsSL "https://api.github.com/repos/oven-sh/bun/releases/latest" \
        | grep "browser_download_url.*bun-windows-x64\.zip" | head -1 | cut -d '"' -f 4)
    if [[ -n "$BUN_URL" ]]; then
        curl -fsSL "$BUN_URL" -o /tmp/bun.zip
        unzip -o /tmp/bun.zip "bun-windows-x64/bun.exe" -d /tmp/bun-extract/
        mv /tmp/bun-extract/bun-windows-x64/bun.exe "$BUN_DIR/bun.exe"
        rm -rf /tmp/bun.zip /tmp/bun-extract
        info "bun installed to $BUN_DIR"
    else
        error "Failed to find bun release URL"
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
# 5. Download standalone tools (oh-my-posh, zoxide)
# ============================================================================
step "5. Standalone tools"

mkdir -p "$WINDOWS_HOME/.local/bin"

# oh-my-posh
if [[ -f "$WINDOWS_HOME/.local/bin/oh-my-posh.exe" ]]; then
    info "oh-my-posh already installed"
else
    warn "Downloading oh-my-posh..."
    curl -fsSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-amd64.exe" \
        -o "$WINDOWS_HOME/.local/bin/oh-my-posh.exe"
    info "oh-my-posh installed"
fi

# zoxide
if [[ -f "$WINDOWS_HOME/.local/bin/zoxide.exe" ]]; then
    info "zoxide already installed"
else
    warn "Downloading zoxide..."
    ZOXIDE_URL=$(curl -fsSL "https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest" \
        | grep "browser_download_url.*x86_64-pc-windows-msvc.zip" | head -1 | cut -d '"' -f 4)
    if [[ -n "$ZOXIDE_URL" ]]; then
        curl -fsSL "$ZOXIDE_URL" -o /tmp/zoxide.zip
        unzip -o /tmp/zoxide.zip zoxide.exe -d "$WINDOWS_HOME/.local/bin/"
        rm -f /tmp/zoxide.zip
        info "zoxide installed"
    else
        error "Failed to find zoxide release URL"
    fi
fi

# ============================================================================
# 5b. ~/.local/bin symlinks
# ============================================================================
step "5b. ~/.local/bin symlinks"

link_bin() {
    local src="$1" name="$2"
    local dst="$WINDOWS_HOME/.local/bin/$name"
    if [[ ! -f "$src" ]]; then
        warn "Skipping symlink for $name: source not found at $src"
        return
    fi
    # Symlink without extension (for zsh/bash)
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        info "Already symlinked: $name"
    else
        ln -sf "$src" "$dst"
        info "Symlinked: $name → $src"
    fi
    # Symlink with .exe extension (for Windows-native callers)
    if [[ "$src" == *.exe ]]; then
        local dst_exe="$WINDOWS_HOME/.local/bin/$name.exe"
        if [[ -L "$dst_exe" && "$(readlink "$dst_exe")" == "$src" ]]; then
            info "Already symlinked: $name.exe"
        else
            ln -sf "$src" "$dst_exe"
            info "Symlinked: $name.exe → $src"
        fi
    fi
}

# MSYS2 usr/bin
link_bin "/usr/bin/zsh.exe"        "zsh"

# MSYS2 mingw64/bin
link_bin "/mingw64/bin/git-lfs.exe" "git-lfs"
link_bin "/mingw64/bin/go.exe"      "go"
link_bin "/mingw64/bin/node.exe"    "node"
link_bin "/mingw64/bin/npm"         "npm"
link_bin "/mingw64/bin/cmake.exe"   "cmake"
link_bin "/mingw64/bin/gcc.exe"     "gcc"
link_bin "/mingw64/bin/ninja.exe"   "ninja"
link_bin "/mingw64/bin/eza.exe"     "eza"
link_bin "/mingw64/bin/fzf.exe"     "fzf"
link_bin "/mingw64/bin/bat.exe"     "bat"

# mingw64 continued
link_bin "/mingw64/bin/python.exe"  "python"
link_bin "/mingw64/bin/python3.exe" "python3"

# bun
link_bin "$WINDOWS_HOME/.bun/bin/bun.exe"   "bun"

# opencode
link_bin "$WINDOWS_HOME/.opencode/bin/opencode.exe" "opencode"

# ============================================================================
# 6. zsh dotfile symlinks
# ============================================================================
step "6. zsh dotfile symlinks"

link_dotfile() {
    local src="$1" dst="$2"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        info "Already symlinked: $dst → $src"
    else
        [[ -f "$dst" && ! -L "$dst" ]] && rm -f "$dst"
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

if [[ -d "$WINDOWS_HOME/.carol" ]]; then
    info "~/.carol already exists"
else
    warn "Cloning carol..."
    git clone https://github.com/jrengmusic/carol.git "$WINDOWS_HOME/.carol"
    info "Cloned carol to ~/.carol"
fi

if [[ -f "$WINDOWS_HOME/.carol/bin/carolcode-x64.exe" ]]; then
    info "carolcode binary already in ~/.carol/bin"
else
    warn "carolcode binary not found in ~/.carol/bin"
    echo "Build from source:"
    echo "  cd ~/Documents/Poems/dev/carolcode"
    echo "  bun install"
    echo "  bun run packages/opencode/script/build.ts --single --skip-install"
    echo "  cp packages/opencode/dist/opencode-windows-x64/bin/carolcode-x64.exe ~/.carol/bin/"
fi

if [[ -L "$WINDOWS_HOME/.local/bin/carol" ]]; then
    info "carol symlink already exists"
else
    ln -sf "$WINDOWS_HOME/.carol/bin/carol" "$WINDOWS_HOME/.local/bin/carol"
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
