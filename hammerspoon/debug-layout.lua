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

return M
