-- Simple debug layout for DAP
-- Clean implementation without debug messages

local M = {}

local debugActive = false
local originalDawFrame = nil
local originalTerminalFrame = nil

-- Detect terminal app
local function getTerminalApp()
  local terminalApps = { 'kitty', 'Alacritty', 'WezTerm', 'iTerm2', 'Terminal', 'END' }
  for _, appName in ipairs(terminalApps) do
    local app = hs.application.find(appName)
    if app then
      return app
    end
  end
  return nil
end

-- Wait for DAW window to appear and capture it
local function waitForDawWindow(dawName, callback)
  local maxAttempts = 30  -- 3 seconds max
  local attempts = 0
  
  local function checkForDaw()
    attempts = attempts + 1
    
    local daw = hs.application.find(dawName)
    
    if daw then
      local dawWindows = daw:allWindows()
      
      if #dawWindows > 0 then
        -- Find window whose title contains DAW app name
        for _, dawWindow in ipairs(dawWindows) do
          local title = dawWindow:title()
          
          -- Check if title contains DAW name (case-insensitive)
          if title:lower():find(dawName:lower()) then
            callback(dawWindow)
            return
          end
        end
      end
    end
    
    if attempts < maxAttempts then
      hs.timer.doAfter(0.1, checkForDaw)
    else
      hs.alert.show('DAW NOT FOUND: ' .. dawName, 2.0)
    end
  end
  
  checkForDaw()
end

-- Setup debug layout: DAW left 50%, Terminal right 50%
function M.setupDebugLayout(dawName)
  if debugActive then
    hs.alert.show('DEBUG ALREADY ACTIVE', 2.0)
    return
  end
  
  waitForDawWindow(dawName, function(dawWindow)
    -- Save original frames
    originalDawFrame = dawWindow:frame()
    
    -- Get terminal
    local terminal = getTerminalApp()
    if not terminal then
      hs.alert.show('NO TERMINAL FOUND', 2.0)
      return
    end
    
    local terminalWindows = terminal:allWindows()
    if #terminalWindows == 0 then
      hs.alert.show('NO TERMINAL WINDOWS', 2.0)
      return
    end
    
    local terminalWindow = terminalWindows[1]
    originalTerminalFrame = terminalWindow:frame()
    
    -- Resize to 50/50
    local screen = hs.screen.mainScreen()
    local frame = screen:frame()
    local halfWidth = frame.w / 2
    local gap = 8
    
    -- DAW on left
    local dawFrame = hs.geometry.rect(frame.x, frame.y, halfWidth, frame.h)
    dawWindow:setFrame(dawFrame)
    
    -- Terminal on right
    local termFrame = hs.geometry.rect(frame.x + halfWidth + gap, frame.y, halfWidth - gap, frame.h)
    terminalWindow:setFrame(termFrame)
    
    debugActive = true
    hs.alert.show('DEBUG LAYOUT: 50/50', 3.0)
  end)
end

-- Restore DAW and terminal to original positions
function M.restoreNormalLayout()
  if not debugActive then
    return
  end
  
  -- Restore DAW
  if originalDawFrame then
    local daw = hs.application.find("REAPER")  -- TODO: Make this generic
    if daw then
      local dawWindows = daw:allWindows()
      for _, win in ipairs(dawWindows) do
        local currentFrame = win:frame()
        -- If window is roughly half-screen width, assume it's our DAW
        if math.abs(currentFrame.w - (hs.screen.mainScreen():frame().w / 2)) < 50 then
          win:setFrame(originalDawFrame)
          break
        end
      end
    end
  end
  
  -- Restore terminal
  if originalTerminalFrame then
    local terminal = getTerminalApp()
    if terminal then
      local terminalWindows = terminal:allWindows()
      if #terminalWindows > 0 then
        terminalWindows[1]:setFrame(originalTerminalFrame)
      end
    end
  end
  
  debugActive = false
  originalDawFrame = nil
  originalTerminalFrame = nil
  hs.alert.show('LAYOUT RESTORED', 3.0)
end

-- Test function to verify Hammerspoon IPC is working
function M.test()
  hs.alert.show('HAMMERSPOON TEST WORKS', 3.0)
end

-- Float standalone app windows (don't tile them in PaperWM)
function M.floatStandaloneApp(appName)
  -- Check if PaperWM is available
  if not PaperWM or not PaperWM.window_filter then
    return
  end
  
  -- Use PaperWM's window filter to exclude this app (same method as DAWs)
  PaperWM.window_filter = PaperWM.window_filter:setAppFilter(appName, false)
  
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

-- Test terminal detection
function M.testTerminal()
  local terminal = getTerminalApp()
  if terminal then
    local windows = terminal:allWindows()
    hs.alert.show('TERMINAL: ' .. terminal:name() .. ' (' .. #windows .. ' windows)', 3.0)
  else
    hs.alert.show('NO TERMINAL FOUND', 3.0)
  end
end

return M