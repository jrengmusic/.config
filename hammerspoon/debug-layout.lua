-- Debug layout management for DAP
-- Arranges windows 50/50 during debugging, restores PaperWM after

local M = {}

local debugActive = false
local originalPaperWMState = nil

-- Detect terminal app (kitty, alacritty, wezterm, etc)
local function getTerminalApp()
  local terminalApps = { 'kitty', 'Alacritty', 'WezTerm', 'iTerm2', 'Terminal' }
  for _, appName in ipairs(terminalApps) do
    local app = hs.application.find(appName)
    if app then
      return app
    end
  end
  return nil
end

-- Get DAW app by name
local function getDawApp(dawName)
  return hs.application.find(dawName)
end

-- Setup debug layout: DAW left 50%, Terminal right 50%
function M.setupDebugLayout(dawName)
  if debugActive then
    return
  end

  local terminal = getTerminalApp()
  local daw = getDawApp(dawName)

  if not terminal or not daw then
    hs.alert.show('Debug setup failed: Terminal or DAW not found')
    return
  end

  -- Focus terminal first to ensure it's available
  terminal:activate()
  hs.timer.usleep(200000)

  local screen = hs.screen.mainScreen()
  local frame = screen:frame()

  -- Calculate 50% width
  local gap = 8
  local halfWidth = (frame.w - gap) / 2

  -- DAW on left 50%
  local dawFrame = hs.geometry.rect(frame.x, frame.y, halfWidth, frame.h)
  daw:mainWindow():setFrame(dawFrame)

  -- Terminal on right 50%
  local termFrame = hs.geometry.rect(frame.x + halfWidth + gap, frame.y, halfWidth, frame.h)
  terminal:mainWindow():setFrame(termFrame)

  -- Disable PaperWM tiling temporarily
  if PaperWM then
    originalPaperWMState = PaperWM.enabled
    PaperWM:stop()
  end

  debugActive = true
  hs.alert.show('Debug layout ready')
end

-- Restore normal layout (full width terminal, re-enable PaperWM)
function M.restoreNormalLayout()
  if not debugActive then
    return
  end

  local terminal = getTerminalApp()
  if terminal then
    -- Restore terminal to full width
    local screen = hs.screen.mainScreen()
    local frame = screen:frame()
    terminal:mainWindow():setFrame(frame)
    terminal:activate()
  end

  -- Re-enable PaperWM
  if PaperWM then
    PaperWM:start()
  end

  debugActive = false
  hs.alert.show('Debug layout restored')
end

-- Focus nvim pane in tmux
function M.focusNvimPane()
  if not debugActive then
    return
  end

  local terminal = getTerminalApp()
  if terminal then
    terminal:activate()
    -- Send tmux command to select adjacent pane
    -- This assumes nvim is in a tmux pane
    hs.timer.usleep(100000)
    hs.eventtap.keyStrokes('C-b')
    hs.timer.usleep(50000)
    hs.eventtap.keyStrokes('l')  -- Move to right pane (nvim)
  end
end

-- Float standalone app windows (don't tile in PaperWM)
-- Generic: works for any app by name
function M.floatStandaloneApp(appName)
  -- Check if PaperWM is available
  if not PaperWM or not PaperWM.window_filter then
    return
  end
  
  -- Use PaperWM's window filter to exclude this app (same method as DAWs)
  PaperWM.window_filter = PaperWM.window_filter:setAppFilter(appName, false)
  hs.alert.show(string.format('Floating %s', appName), 1)
  
  -- Bring app to front (wait for window to appear)
  local function activateApp()
    local app = hs.application.find(appName)
    
    if app then
      local windows = app:allWindows()
      
      if #windows > 0 then
        -- Activate app to bring windows to front
        app:activate()
        
        -- Remove from PaperWM management if it got tiled
        local floated = 0
        for _, win in ipairs(windows) do
          if PaperWM.windows and PaperWM.windows[win:id()] then
            PaperWM.windows[win:id()] = nil
            floated = floated + 1
          end
        end
        
        -- Force retile to remove floated windows from layout
        if floated > 0 then
          local space = hs.spaces.focusedSpace()
          local screen = hs.screen.mainScreen()
          if PaperWM.tiling and PaperWM.tiling.tileSpace then
            PaperWM.tiling.tileSpace(space, screen)
          end
        end
      else
        -- Windows not ready yet, retry
        hs.timer.doAfter(0.5, activateApp)
      end
    end
  end
  
  -- Start activation with small delay
  hs.timer.doAfter(0.2, activateApp)
end

return M
