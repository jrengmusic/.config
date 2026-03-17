# DAP Standalone App Float Integration

## Goal
When debugging standalone JUCE apps, automatically make the app window **float** (not tiled) in PaperWM. This allows the debugged app to appear as an overlay instead of being tiled into the window layout.

## How It Works

### 1. **Auto-Detection**
- When `<leader>C-r` is pressed, nvim detects if it's a standalone project
- After launching the standalone app via DAP, a listener extracts the app name
- Hammerspoon is called to tell PaperWM to float that app's windows

### 2. **Generic Implementation**
- **No hardcoding**: Works for any app name
- **No manual setup**: Automatically extracts app name from executable path
- **Configurable**: Easy to modify PaperWM integration method

### 3. **Flow Diagram**
```
User presses <leader>C-r
  ↓
Nvim detects: standalone project
  ↓
Build succeeds → DAP launches app
  ↓
DAP listener fires (after.launch)
  ↓
Extract app name: /path/to/MyApp.app → "MyApp"
  ↓
Call: hs -c "require('debug-layout').floatStandaloneApp('MyApp')"
  ↓
Hammerspoon finds app windows
  ↓
PaperWM.windows[windowID] = false (mark as non-managed)
  ↓
App window floats! ✓
```

## Files Modified

### 1. `~/.config/nvim/lua/dap/dapui_config.lua`
**Added:** `dap.listeners.after.launch.standalone_float`
- Triggers only for standalone projects
- Extracts app name from executable path
- Calls Hammerspoon after 500ms delay (ensures window appears)

### 2. `~/.config/hammerspoon/debug-layout.lua`
**Added:** `M.floatStandaloneApp(appName)`
- Finds app by name (generic)
- Gets all windows for that app
- Tries multiple PaperWM float methods:
  - Method 1: `PaperWM.windows[winID] = false` (mark non-managed)
  - Method 2: `PaperWM:floatWindow(win)` (if available)
  - Method 3: `PaperWM:setFloat(win, true)` (if available)
- Auto-detects which method works
- Prints debug info if float fails

## Testing

### Test 1: Basic Float
1. Open standalone JUCE project (e.g., END)
2. Press `<leader>C-r`
3. Select build scheme (Debug/Release)
4. Wait for build + launch
5. **Verify:** App window appears floating (not tiled)

### Test 2: Different Projects
1. Test with different standalone app names
2. Verify generic implementation works for all

### Test 3: No Impact on Plugins
1. Open plugin JUCE project
2. Press `<leader>C-r`
3. **Verify:** Plugin flow unchanged (DAW layout 50/50)

### Test 4: PaperWM Method Detection
1. Check Hammerspoon console: `hs -c "hs.console.show()"`
2. Look for: `[debug-layout] Floated N window(s) for: AppName`
3. If warning appears, check which PaperWM methods are available

## Debugging

### Check App Name Extraction
```lua
-- In nvim, after launching:
:lua print(vim.inspect(require('dap').session().config.program))
```

### Check PaperWM Methods
```lua
-- In Hammerspoon console:
for k,v in pairs(PaperWM) do
  if type(v) == 'function' then print(k) end
end
```

### Manual Test Hammerspoon Function
```lua
-- In Hammerspoon console:
require('debug-layout').floatStandaloneApp('END')
```

### Check if PaperWM is Managing Window
```lua
-- In Hammerspoon console:
app = hs.application.find('END')
win = app:mainWindow()
print(PaperWM.windows[win:id()])  -- Should be false if floated
```

## Configuration

### Change Float Delay
**File:** `lua/dap/dapui_config.lua`
```lua
vim.defer_fn(function()
  vim.fn.system(...)
end, 500)  -- Change this value (milliseconds)
```

### Disable Float for Specific Apps
**File:** `hammerspoon/debug-layout.lua`
```lua
function M.floatStandaloneApp(appName)
  -- Add filter
  local skipApps = { 'SomeApp', 'AnotherApp' }
  if vim.tbl_contains(skipApps, appName) then
    return
  end
  -- ... rest of function
end
```

### Use Different PaperWM Method
**File:** `hammerspoon/debug-layout.lua`
```lua
-- Replace Method 1 section with your preferred API:
if PaperWM.yourCustomMethod then
  PaperWM:yourCustomMethod(win, params)
  success = true
end
```

## Troubleshooting

### Problem: App Still Gets Tiled
**Solution 1:** Check PaperWM is running
```bash
hs -c "print(PaperWM ~= nil)"  # Should print: true
```

**Solution 2:** Check delay is sufficient
- Increase delay in `dapui_config.lua` from 500ms to 1000ms

**Solution 3:** Check app name extraction
```lua
-- In nvim after launch:
:lua print(vim.inspect(require('dap').session().config.program))
```

### Problem: "PaperWM not loaded"
- Ensure PaperWM is installed and loaded in Hammerspoon
- Check `~/.hammerspoon/init.lua` loads PaperWM

### Problem: "App not found"
- App name might not match
- Check: `hs -c "print(hs.application.find('YourAppName'))"`
- Try variations: "MyApp", "MyApp.app", "MyApp DEBUG"

### Problem: PaperWM Method Not Found
- Check Hammerspoon console output
- Function will list available PaperWM float methods
- Update `debug-layout.lua` to use correct method name

## Plugin vs Standalone Behavior

| Feature | Plugin | Standalone |
|---------|--------|------------|
| Build target | VST3/AU/VST/AAX | App bundle |
| Launch | DAW process | App process |
| Window layout | 50/50 (DAW/Terminal) | Float app window |
| Config file | `.nvim-dap-config` | `.nvim-standalone-config` |
| PaperWM | Disabled during debug | App floated only |

## Future Enhancements

### Option 1: Custom Float Rules
Allow per-project float settings in `.nvim-standalone-config`:
```lua
return {
  buildScheme = "Debug",
  float = true,  -- Optional: override default
  floatDelay = 500,  -- Optional: custom delay
}
```

### Option 2: Focus Control
After floating, optionally focus or not focus the app:
```lua
function M.floatStandaloneApp(appName, shouldFocus)
  -- ... float logic ...
  if shouldFocus then
    app:activate()
  end
end
```

### Option 3: Position Control
Float app at specific position/size:
```lua
function M.floatStandaloneApp(appName, geometry)
  -- ... float logic ...
  if geometry then
    win:setFrame(geometry)
  end
end
```

## Summary
- ✅ Generic: Works for any standalone app
- ✅ Automatic: No manual window management needed
- ✅ Isolated: Doesn't affect plugin debugging workflow
- ✅ Configurable: Easy to customize PaperWM integration
- ✅ Robust: Auto-detects which PaperWM method to use
- ✅ Debuggable: Comprehensive logging and error messages
