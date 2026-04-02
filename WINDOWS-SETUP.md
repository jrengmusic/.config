# Windows Development Environment Setup

Identical DX to macOS across all machines. Config repo (`~/.config/`) is the single source of truth.

## Architecture

```
Machine              OS              Terminal    Shell    Compiler
─────────────────────────────────────────────────────────────────
iMac 5K 2015         macOS Monterey  kitty       zsh      clang (Xcode)
iMac 5K 2015         Windows 10      END         zsh      cl.exe (MSVC)
MBP M4               macOS latest    kitty       zsh      clang (Xcode)
MBP M4               Windows 11 UTM  END         zsh      cl.exe (MSVC)
```

## Which MSYS2 Shell to Launch

> **Intel x86_64 = AMD64** — same instruction set. AMD invented 64-bit x86, Intel adopted it.
> "x86_64", "x64", "AMD64" all mean the same thing. Use the same shell.

| Machine | CPU | Windows | MSYS2 Shell | `$MSYSTEM` |
|---|---|---|---|---|
| iMac 5K 2015 | Intel Core i5/i7 (x86_64) | Windows 10 | **MINGW64** | `MINGW64` |
| MBP M4 (UTM) | Apple M4 → ARM64 guest | Windows 11 ARM64 | **CLANGARM64** | `CLANGARM64` |

**Why these and not the others:**

| Environment | Use case | Notes |
|---|---|---|
| `MSYS` | Script running only | No Windows toolchain. Avoid for dev work. |
| `MINGW64` | x86_64 native dev | GCC toolchain. Our x64 choice. |
| `UCRT64` | x86_64 (modern runtime) | Like MINGW64 but newer C runtime. Not needed here. |
| `CLANG64` | x86_64 Clang toolchain | x64 but Clang-based. Not needed — we use MSVC for builds. |
| `CLANGARM64` | ARM64 native dev | ARM64 Clang toolchain. Our ARM64 choice. |
| `MINGW32` | 32-bit x86 | Legacy. Never use. |

**How to launch the right shell:**

After installing MSYS2, the Start Menu has shortcuts for each environment. Launch:
- **iMac / any x64 machine** → `MSYS2 MINGW64`
- **MBP M4 UTM / any ARM64 machine** → `MSYS2 CLANGARM64`

The shell sets `$MSYSTEM` automatically. The setup script reads `$MSYSTEM` to pick the right package prefix and paths — no manual configuration needed.

All machines share the same config repo. OS-specific behavior is handled by:
- **zsh**: `$OPERATING_SYSTEM` variable (`windows`, `macos-arm`, `macos-intel`)
- **nvim/lua**: `vim.fn.has('win32') == 1`
- **shell scripts**: `$OSTYPE` check (`msys`, `cygwin`, `darwin`)

## Prerequisites

Install these manually before running the setup script:

1. **MSYS2** — https://www.msys2.org/ (install to `C:\msys64`)
   - On ARM64 Windows (UTM on Apple Silicon): install MSYS2 ARM64, then launch via **CLANGARM64** shortcut
   - On x64 Windows: install MSYS2 x64, launch via **MINGW64** shortcut
2. **Visual Studio 2022+** — with "Desktop development with C++" workload (provides vcvarsall.bat, MSVC linker, headers)
3. **LLVM** — `winget install LLVM.LLVM` (provides clang-cl compiler + clangd LSP)
4. **Neovim** — `winget install Neovim.Neovim`

Everything else (git, go, node, npm, bun, python, cmake, ninja, eza, fzf, bat, zoxide, oh-my-posh) is installed by the setup script.

> **ARM64 note:** `uname -m` always returns `x86_64` in every MSYS2 environment — the MSYS2 runtime is an x64 binary running under Windows x64 emulation ([msys2-runtime#171](https://github.com/msys2/msys2-runtime/issues/171)). `PROCESSOR_ARCHITECTURE` is also unreliable: Windows reports `AMD64` for x64 bash processes even on ARM64 hardware ([MSYS2-packages#4960](https://github.com/msys2/MSYS2-packages/issues/4960)).
>
> The scripts use `$MSYSTEM` — the canonical method used by MSYS2 and Git for Windows. Launch the **CLANGARM64** terminal shortcut on ARM64 hardware; the script sees `MSYSTEM=CLANGARM64` and selects `mingw-w64-clang-aarch64-*` packages automatically. A secondary check on `uname -s` (which carries a `-ARM64` suffix on ARM64 hosts via [msys2-runtime PR#244](https://github.com/msys2/msys2-runtime/pull/244)) warns if you launched the wrong shell.

## Quick Start

### Bootstrap (fresh machine — do this once)

MSYS2 ships without git or openssh. Before setup.sh can run you need both and your SSH key.

```sh
# 1. Launch MSYS2 as Administrator (CLANGARM64 on ARM64, MINGW64 on x64)

# 2. Update and install bootstrap deps
pacman -Syu
pacman -S git openssh

# 3. Copy SSH keys in (from USB, another machine, etc.)
mkdir -p ~/.ssh
# copy id_ed25519 and id_ed25519.pub into ~/.ssh/
chmod 600 ~/.ssh/id_ed25519

# 4. Clone to Windows home directly.
#    IMPORTANT: at this point MSYS2 home is still /home/<user>, not /c/Users/<user>.
#    setup.sh switches it — but you need .config there first.
git clone git@github.com:jrengmusic/.config.git /c/Users/$(whoami)/.config

# 5. Run setup
bash /c/Users/$(whoami)/.config/setup.sh
```

> Must run as Administrator — the script writes to system PATH.
> Launch via **CLANGARM64** shortcut on ARM64 Windows, **MINGW64** on x64.

Then restart MSYS2 and launch nvim to install Mason tools:

```vim
:MasonInstall lua_ls pyright ts_ls zls stylua prettier codelldb
```

Note: Do NOT install clangd via Mason on Windows. Use the system clangd from `winget install LLVM.LLVM`.

## What the Setup Script Does

### 1. MSYS2 Home Directory

Changes `/etc/nsswitch.conf` so MSYS2 uses the Windows home (`C:\Users\<name>`) instead of `/home/<name>`:

```
db_home: windows
```

This means `~` = `/c/Users/<name>` = `C:\Users\<name>`. SSH keys, config files, Documents — all in one place.

### 2. Native Symlinks

Enables native Windows symlinks in the arch-specific ini (`/c/msys64/mingw64.ini` on x64, `/c/msys64/clangarm64.ini` on ARM64):

```
MSYS=winsymlinks:nativestrict
```

Required for `ln -s` to create real Windows symlinks (needed for nvim config).

### 3. Windows Environment Variables

Sets these as **Windows user environment variables** (persistent across reboots):

| Variable | Value | Purpose |
|---|---|---|
| `MSYS` | `winsymlinks:nativestrict` | Native symlinks everywhere |
| `MSYSTEM` | `MINGW64` (x64) or `CLANGARM64` (ARM64) | Use correct toolchain for host arch |
| `MSYS2_PATH_TYPE` | `inherit` | Inherit Windows PATH |
| `XDG_CONFIG_HOME` | `C:\Users\<name>\.config` | nvim and tools use `~/.config/` as SSOT (same as macOS) |
| `CLAUDE_CODE_GIT_BASH_PATH` | `C:\msys64\usr\bin\bash.exe` | Claude Code uses MSYS2 bash (no Git for Windows) |

Also adds to **Windows system PATH**:
- `C:\msys64\usr\bin` — zsh, git, unzip
- `C:\msys64\mingw64\bin` (x64) or `C:\msys64\clangarm64\bin` (ARM64) — toolchain binaries
- `C:\Users\<name>\.local\bin` — all tool symlinks (single PATH entry for everything)

### 4. MSYS2 Packages

Via `pacman` (prefix is `mingw-w64-x86_64-` on x64, `mingw-w64-clang-aarch64-` on ARM64):
- `zsh`, `git`, `unzip`
- `<prefix>-git-lfs`
- `<prefix>-go`
- `<prefix>-nodejs` (includes npm)
- `<prefix>-python`, `<prefix>-python-pip`, `<prefix>-python-pipx`
- `<prefix>-eza`, `<prefix>-fzf`, `<prefix>-bat`, `<prefix>-gcc`
- `<prefix>-gdb`, `<prefix>-fd`, `<prefix>-ripgrep`

### 4b. Bun

Downloaded from GitHub releases to `~/.bun/bin/bun.exe`.

### 4c. zsh-syntax-highlighting

Not in MSYS2 repos — cloned from source to `/usr/share/zsh-syntax-highlighting`.

### 5. Standalone Tools

Downloaded directly to `~/.local/bin/`:
- `oh-my-posh.exe` — prompt theme engine
- `zoxide.exe` — smart cd

### 5b. ~/.local/bin Symlinks

All tool binaries are symlinked into `~/.local/bin/` — the single directory on system PATH:

| symlink | source |
|---|---|
| `zsh` | `/usr/bin/zsh.exe` |
| `git-lfs` | `/mingw64/bin/git-lfs.exe` |
| `go` | `/mingw64/bin/go.exe` |
| `node` | `/mingw64/bin/node.exe` |
| `npm` | `/mingw64/bin/npm` |
| `cmake` | `/mingw64/bin/cmake.exe` |
| `gcc` | `/mingw64/bin/gcc.exe` |
| `ninja` | `/mingw64/bin/ninja.exe` |
| `eza` | `/mingw64/bin/eza.exe` |
| `fzf` | `/mingw64/bin/fzf.exe` |
| `bat` | `/mingw64/bin/bat.exe` |
| `python` | `/mingw64/bin/python.exe` |
| `python3` | `/mingw64/bin/python3.exe` |
| `bun` | `~/.bun/bin/bun.exe` |
| `carol` | `~/.carol/bin/carol` |

### 6. zsh Dotfile Symlinks

`~/.zshrc` and `~/.zprofile` are symlinked directly to `~/.config/zsh/zshrc` and `~/.config/zsh/zprofile` — same as macOS.

### 7. Neovim Config

With `XDG_CONFIG_HOME=C:\Users\<name>\.config` set as a Windows env var, nvim reads `~/.config/nvim` directly — no symlink needed. Same as macOS.

### 9. Carol + Claude Code

| Tool | Binary Location | Command | Install Method |
|---|---|---|---|
| Claude Code | npm global | `claude` | `npm install -g @anthropic-ai/claude-code` |
| carol (script) | `~/.carol/bin/carol` → `~/.local/bin/carol` | `carol` | Symlink from cloned repo |

**Claude Code on Windows**: The native installers (`.ps1`, `.cmd`) do not work under MSYS2/zsh. npm is the only working method. Ignore the "moving to native installation" warning — it does not apply here. The `CLAUDE_CODE_GIT_BASH_PATH` env var must point to MSYS2 bash since Git for Windows is not installed.

Clone carol repo:

```sh
git clone git@github.com:jrengmusic/carol.git ~/.carol
```

## Key Differences from macOS

### Terminal

nvim's `:terminal` on Windows uses `vim.o.shell` which defaults to `zsh.exe` (MSYS2). This means:
- `:terminal` opens zsh, not cmd.exe
- `.bat` files need `jobstart({script.bat, arg1}, {term=true})` to run via cmd.exe
- `.sh` files need `jobstart({'bash', script.sh, arg1}, {term=true})`
- `vim.fn.termopen()` is used on macOS, `vim.fn.jobstart()` with `term=true` on Windows

### Build Pipeline

JUCE explicitly rejects MinGW (`#error "MinGW is not supported"`), so builds require MSVC environment.

**Compiler**: `clang-cl` (from LLVM) — MSVC-compatible frontend that produces **DWARF** debug symbols, which codelldb/LLDB can read natively. This gives identical debugging experience to macOS.

**Why not `cl.exe`?** MSVC produces PDB debug symbols. codelldb uses LLDB which has limited PDB support. By using clang-cl with `-gdwarf`, we get DWARF symbols on both platforms — same debugger, same behavior.

**Why not MinGW GCC?** JUCE hardcodes `#error "MinGW is not supported"`.

| Script | Platform | Purpose |
|---|---|---|
| `build-debug.sh` | macOS | Build with clang via cmake+ninja |
| `build-debug.bat` | Windows | vcvarsall.bat + clang-cl + cmake+ninja |
| `clean-build.sh` | Both | Delete `Builds/Ninja/` (no compiler needed) |

The `.bat` file:
1. Calls `vcvarsall.bat x64` — sets up MSVC linker, headers, and libraries
2. Sets `CC`/`CXX` to `clang-cl` from `C:\Program Files\LLVM\bin\`
3. Passes `-gdwarf /EHsc -fms-compatibility` flags
4. Runs cmake + ninja

**Known issue**: clang-cl 22.x has a regression with `auto x { expr }` brace initialization and JUCE's `Array` template `initializer_list` constructor (LLVM #136203/#138307). Workaround: use `auto x = expr` instead of `auto x { expr }` for JUCE container return values.

### LSP (clangd)

| | macOS | Windows |
|---|---|---|
| Binary | Mason's clangd | System clangd (winget LLVM) |
| `--query-driver` | `/usr/bin/c++,/usr/bin/clang++` | `/mingw64/bin/g++` |

Mason's clangd on Windows is a `.cmd` wrapper that nvim can't execute directly. The system clangd from LLVM works.

### DAP (codelldb)

codelldb is used on both platforms. On macOS, clang produces DWARF symbols. On Windows, clang-cl produces DWARF symbols with `-gdwarf`. Same adapter, same debug format, same experience.

**vsdbg (Microsoft's debugger) won't work** — it's licensed exclusively for VS Code and rejects nvim as a client.

| | macOS | Windows |
|---|---|---|
| Adapter | codelldb (Mason) | codelldb (Mason) |
| Debug symbols | DWARF (clang) | DWARF (clang-cl with `-gdwarf`) |
| Process lookup | `pgrep -x 'DAW'` | `tasklist /FI "IMAGENAME eq DAW.exe"` |
| Kill process | `killall DAW` | `taskkill /F /IM DAW` |
| DAW launch delay | 2000ms | 3000ms |
| Plugin formats | VST3, AU, VST, AAX | VST3, VST, AAX (no AU) |
| DAW scan path | `/Applications/*.app` | `C:/Program Files/*/*.exe` |

### Paths

`vim.fn.stdpath('config')` returns `C:\Users\<name>\AppData\Local\nvim` on Windows (backslashes). When passing to zsh or MSYS2 tools, convert with:

```lua
local function toMsys(p)
  return p:gsub('\\', '/'):gsub('^(%a):', function(d) return '/' .. d:lower() end)
end
-- C:\Users\jreng → /c/Users/jreng
```

This conversion is only needed for paths passed to bash/zsh. Paths passed to cmd.exe (`.bat` files) work as-is.

### Windows-specific Commands

| macOS | Windows (MSYS2) |
|---|---|
| `pgrep` | `tasklist` |
| `killall` | `taskkill /F /IM` |
| `find /Applications -name "*.app"` | `vim.fn.glob('C:/Program Files/*/*.exe')` |
| `open` | `start` |

## nvim Keybindings (Build)

All keybindings work identically on macOS and Windows:

| Key | Action |
|---|---|
| `<leader>bk` | Clean build directory |
| `<leader>bb` | Build only |
| `<leader>bc` | Clean + build |
| `<leader>br` | Build + launch DAW + attach DAP |
| `<F5>` | Configure DAP (format/DAW/scheme dialog) |
| `<leader>dt` | Terminate DAP + kill DAW |

Terminal behavior on build:
- **Success**: terminal auto-closes, LSP restarts
- **Failure**: terminal stays open (read-only), press `q` to close

## File Map

```
~/.config/                              # SSOT for all machines
├── WINDOWS-SETUP.md                    # This file
├── setup.sh                            # Automated setup script (arch-aware: x64 + ARM64)
├── reset.sh                            # Teardown script (arch-aware)
├── end/
│   └── end.lua                         # END terminal config (OS-branched)
├── zsh/
│   ├── zprofile                        # PATH, env vars (OS-branched)
│   └── zshrc                           # Aliases, plugins (OS-branched)
└── nvim/
    ├── lua/
    │   ├── core/
    │   │   ├── keymaps.lua             # Build keymaps (OS-branched terminal)
    │   │   └── options.lua             # Editor options
    │   ├── dap/
    │   │   └── configurations.lua      # DAP config (OS-branched DAW detection)
    │   ├── lsp/
    │   │   └── clangd.lua              # clangd config (OS-branched binary + query-driver)
    │   └── plugins/
    │       └── syntax.lua              # Treesitter config
    └── scripts/
        ├── build-debug.sh              # macOS build (clang + cmake + ninja)
        ├── build-debug.bat             # Windows build (clang-cl + MSVC env + cmake + ninja)
        └── clean-build.sh             # Clean (cross-platform, no compiler)

~/.zshrc → ~/.config/zsh/zshrc          # Symlink (same as macOS)
~/.zprofile → ~/.config/zsh/zprofile   # Symlink (same as macOS)
~/.local/bin/                           # All tool symlinks (single PATH entry)
~/.carol/                               # Carol repo + carol script
~/.local/bin/claude                     # Claude Code (npm global symlink)

/c/msys64/etc/nsswitch.conf             # MSYS2: db_home: windows
/c/msys64/mingw64.ini                   # MSYS2: native symlinks, MSYSTEM
```

## Troubleshooting

### "MinGW is not supported" error during build
The build is using GCC instead of clang-cl. Make sure `leader bb`/`bc`/`br` uses `build-debug.bat` (not `.sh`). The `.bat` sets up MSVC env then uses clang-cl as the compiler.

### `auto x { expr }` brace-init errors with clang-cl
clang 22.x has a regression (LLVM #136203) where `auto x { expr }` with JUCE's `Array` template `initializer_list` constructor is incorrectly preferred over copy/move constructors. Workaround: use `auto x = expr` instead. This does NOT affect macOS clang.

### clangd not starting
Mason's clangd is a `.cmd` file that nvim can't run. Install system clangd: `winget install LLVM.LLVM`. The config in `clangd.lua` auto-selects system clangd on Windows.

### "DAW not running" error on `leader br`
The DAW hasn't started within the 3-second delay. Either increase the delay in `keymaps.lua` or launch the DAW manually before running `leader br`.

### vsdbg / cppvsdbg won't work
Microsoft's vsdbg debugger is licensed exclusively for VS Code. It validates the client and rejects nvim. Use codelldb with DWARF symbols instead.

### Symlinks fail with "Permission denied"
Ensure `MSYS=winsymlinks:nativestrict` is set as a Windows user environment variable. May also need Developer Mode enabled in Windows Settings > For developers.

### Terminal shows garbled paths
nvim's `stdpath('config')` returns Windows paths with backslashes. Use `toMsys()` when passing paths to bash/zsh. Paths to `.bat` files via `jobstart` work with Windows paths as-is.
