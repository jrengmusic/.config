# Neovim DAP Build & Debug Workflow for JUCE Plugins

## Summary

Integrated build + debug workflow for JUCE audio plugins in Neovim using codelldb DAP adapter.

## Key Features

### 1. One-Key Build + Debug (`<leader><C-r>`)
- Builds project with configurable scheme (Debug/Release)
- Launches configured DAW automatically on success
- Attaches debugger to DAW process (for plugin debugging)
- Terminal auto-closes on successful build, stays open on failure

### 2. DAP Configuration Dialog (`<F5>`)
- First-run dialog to configure: plugin format (VST3/AU/VST/AAX), build scheme, DAW path
- Saves to `.nvim-dap-config` in project root
- Auto-validates config on load, prompts reconfiguration if invalid

### 3. Clean Build (`<leader><C-k>`)
- Wipes build directory and reconfigures CMake

## Fixes Applied

| Issue | Root Cause | Fix |
|-------|------------|-----|
| `new_view` nil error | `dap/ui.lua` shadowing nvim-dap internal module | Renamed to `dap/dapui_config.lua` |
| Build scheme not respected | CMake cache not reconfigured on scheme change | `build-debug.sh` checks `CMAKE_BUILD_TYPE` in cache |
| Slow Release builds (~15 min) | LTO + universal binary (x86_64 + arm64) | Native arch only + LTO disabled for Ninja |
| Terminal not scrolling | Missing auto-scroll on terminal output | Added autocmd for `TermRequest`, `TextChangedT`, `CursorMovedI` |
| `${port}` connection refused | `type = 'server'` with port substitution failing | Changed to `type = 'executable'` (stdio, codelldb 1.11.0+) |
| DAP not initialized before run | Lazy loading race condition | Explicit adapter/config setup before `dap.run()` |

## Files Modified

```
~/.config/nvim/
├── lua/
│   ├── core/keymaps.lua          # Build+debug keymap, terminal auto-close
│   ├── dap/
│   │   ├── adapters.lua          # codelldb executable mode
│   │   ├── configurations.lua    # DAP configs + .nvim-dap-config management
│   │   └── dapui_config.lua      # DAP UI setup (renamed from ui.lua)
│   └── plugins/dap.lua           # Lazy loading setup
└── scripts/
    ├── build-debug.sh            # Build script with scheme detection
    └── clean-build.sh            # Clean + reconfigure

~/Documents/Poems/kuassa/___lib___/cmake/
└── KuassaPlugin.cmake            # LTO conditional (Xcode only)
```

## Usage

1. Open JUCE plugin project in nvim
2. Press `<leader><C-r>` (first time: configure format, scheme, DAW)
3. Build runs in terminal split
4. On success: terminal closes, DAW launches, debugger attaches
5. Set breakpoints with `<leader>db`, step with F10/F11/F12
6. Terminate with `<leader>dt` (also kills DAW)

## Requirements

- codelldb 1.11.0+ (via Mason)
- CMake + Ninja
- JUCE project with KANJUT build system
