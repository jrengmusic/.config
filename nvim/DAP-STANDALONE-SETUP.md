# DAP Standalone + Plugin Unified Workflow

## Summary
Unified DAP/LSP workflow that automatically detects JUCE project type (plugin vs standalone) and uses the appropriate build and debug flow.

## Key Features

### 1. **Auto-Detection**
- Detects project type by checking `CMakeLists.txt`:
  - `juce_add_plugin` → Plugin project
  - `juce_add_console_app` or `juce_add_gui_app` → Standalone project
- Fallback: checks build directory structure

### 2. **Unified Keybindings**
- **`<leader>C-r`** - Build + Launch + Debug (auto-detects project type)
  - **Plugin**: Asks format (VST3/AU/VST/AAX) + DAW + build scheme → builds → launches DAW → attaches
  - **Standalone**: Asks build scheme (Debug/Release) → builds → launches app → attaches
- **`F5`** - Configure project (shows appropriate dialog based on project type)
- **`<leader>dt`** - Terminate debugger + close DAW/app (auto-detects)

### 3. **Auto-Save Before Build**
- Automatically saves all open buffers before building (`silent! wa`)

### 4. **Config Files**
- **Plugin**: `.nvim-dap-config` (stores: format, DAW path, DAW name, build scheme)
- **Standalone**: `.nvim-standalone-config` (stores: build scheme only)

## Code Improvements

### SSOT Refactoring
- **Shared terminal handler** (`runBuildInTerminal`) eliminates ~80 lines of duplication
- Terminal auto-scroll and exit handling unified for both plugin and standalone flows

### Project Type Detection Guards
- `getDawPid()` now checks project type before calling plugin config
- DAP UI listeners check project type before loading plugin-specific config
- Prevents plugin dialogs from appearing in standalone projects

### Build Script Improvements
- Supports "Standalone" format (searches for `_App` targets)
- Shows available targets on error for debugging

### DAP Configuration Improvements
- Standalone executable finder updated for correct JUCE paths:
  - `*App_artefacts*/Debug/*.app` (not `/Standalone/` subdirectory)
- Error messages include helpful context

## File Structure
```
.config/nvim/
├── lua/
│   ├── core/
│   │   └── keymaps.lua          # Unified <leader>C-r with auto-detection
│   ├── dap/
│   │   ├── adapters.lua         # codelldb setup
│   │   ├── configurations.lua   # Project detection + config management
│   │   └── dapui_config.lua     # UI with project type guards
│   └── plugins/
│       └── dap.lua              # Lazy loading configuration
└── scripts/
    ├── build-debug.sh           # Handles both plugin and standalone builds
    └── clean-build.sh
```

## Usage

### First Time Setup (Per Project)
1. Open project in nvim
2. Press `F5` to configure:
   - **Plugin**: Select format, DAW, and build scheme
   - **Standalone**: Select build scheme only
3. Config saved automatically

### Daily Workflow
1. Edit code
2. Press `<leader>C-r` to build and debug
   - Auto-saves all files
   - Auto-detects project type
   - Builds appropriate target
   - Launches and attaches debugger

### Reconfigure
- Press `F5` anytime to change settings

## Plugin Flow Verification
✓ Detects plugin projects correctly
✓ Shows format + DAW + scheme dialog on first run
✓ Builds plugin (VST3/AU/VST/AAX)
✓ Copies to system plugin directory
✓ Launches DAW
✓ Attaches debugger to DAW process
✓ Kills DAW on `<leader>dt`

## Standalone Flow Verification
✓ Detects standalone projects correctly
✓ Shows scheme dialog only (Debug/Release)
✓ Builds standalone app
✓ Launches app directly
✓ Attaches debugger to app process
✓ Terminates app on `<leader>dt`

## Changes Summary
- 5 files modified
- +317 lines added (new features)
- -94 lines removed (debug + duplication)
- Net: More functionality with cleaner code
