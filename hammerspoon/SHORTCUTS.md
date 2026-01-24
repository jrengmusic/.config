# Hammerspoon Keyboard Shortcuts

## PaperWM (Tiling Window Manager)

### Modal Mode
Enter modal mode with `Ctrl+Space`. Press `Escape` to exit.

| Shortcut | Action |
|----------|--------|
| `H` | Focus window left |
| `J` | Focus window down |
| `K` | Focus window up |
| `L` | Focus window right |
| `1-9` | Focus window at position |
| `Tab` | Full width |
| `=` | Increase width |
| `-` | Decrease width |
| `Return` | Center window |
| `Space` | Toggle floating |
| `Escape` | Exit modal mode |

### Default Hotkeys (when modal is disabled)
These are available when not in modal mode:

| Shortcut | Action |
|----------|--------|
| `Alt+Cmd+Left` | Focus window left |
| `Alt+Cmd+Right` | Focus window right |
| `Alt+Cmd+Up` | Focus window up |
| `Alt+Cmd+Down` | Focus window down |
| `Alt+Cmd+Shift+Left` | Swap window left |
| `Alt+Cmd+Shift+Right` | Swap window right |
| `Alt+Cmd+Shift+Up` | Swap window up |
| `Alt+Cmd+Shift+Down` | Swap window down |
| `Alt+Cmd+C` | Center window |
| `Alt+Cmd+F` | Full width |
| `Alt+Cmd+R` | Cycle width |
| `Alt+Cmd+Shift+R` | Cycle height |
| `Alt+Cmd+I` | Slurp in |
| `Alt+Cmd+O` | Barf out |
| `Alt+Cmd+Escape` | Toggle floating |
| `Alt+Cmd+Shift+F` | Focus floating |
| `Alt+Cmd+,` | Switch space left |
| `Alt+Cmd+.` | Switch space right |
| `Alt+Cmd+1-9` | Switch to space |
| `Alt+Cmd+Shift+1-9` | Move window to space |

## Function Keys

Toggle between Function mode and Control mode by pressing `Fn` key or clicking the menubar icon.

### Control Mode (media/system keys)
| Shortcut | Action |
|----------|--------|
| `F1` | Brightness down |
| `F2` | Brightness up |
| `-` | Keyboard backlight down |
| `=` | Keyboard backlight up |
| `F7` | Previous track |
| `F8` | Play/Pause |
| `F9` | Next track |
| `F10` | Mute |
| `F11` | Volume down |
| `F12` | Volume up |

### Function Mode
Standard F1-F12 keys work as normal function keys.

## System Power
| Shortcut | Action |
|----------|--------|
| `Alt+Cmd+F12` | Put Mac to sleep |
| `Ctrl+Cmd+F12` | Force restart (no save prompt) |
| `Ctrl+Alt+Cmd+F12` | Shutdown (prompts to save) |

## Xcode (automatic when Xcode is active)
| Shortcut | Action |
|----------|--------|
| `Escape` | Format code with clang-format, then exit to normal mode |
| `Cmd+Space` | Open Quickly (instead of Spotlight) |

## Menubar Icons

- **Caffeine**: Click to toggle display sleep prevention
- **Fn**: Click to toggle between Function/Control mode

## Auto Features

- **Config Reload**: Automatically reloads when any `.lua` file in `~/.hammerspoon/` is modified
- **App Watcher**: Automatically enables caffeine and disables hotkeys when REAPER, Blender, DaVinci Resolve, or Fusion is active
