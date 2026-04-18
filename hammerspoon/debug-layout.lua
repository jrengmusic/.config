-- DAP-related Hammerspoon helpers

local M = {}

-- Detect terminal app
local function getTerminalApp()
  return hs.application.find('END')
end

-- Test function to verify Hammerspoon IPC is working
function M.test()
  hs.alert.show('HAMMERSPOON TEST WORKS', 3.0)
end

-- Float standalone app windows (don't tile them in PaperWM)
-- Uses per-window floating (toggleFloating) rather than setAppFilter, so that
-- apps like END whose name matches the regular terminal are not globally
-- excluded from tiling — only the specific newly-launched windows are floated.
function M.floatStandaloneApp(appName)
  if not PaperWM or not PaperWM.floating then
    return
  end

  local maxAttempts = 20  -- 2 seconds
  local attempts = 0

  local function tryFloat()
    attempts = attempts + 1
    local app = hs.application.find(appName)

    if app then
      local windows = app:allWindows()
      if #windows > 0 then
        app:activate()
        for _, win in ipairs(windows) do
          -- Only float windows that are currently tiled (not already floating)
          if not PaperWM.floating.isFloating(win) then
            PaperWM.floating.toggleFloating(win)
          end
        end
        return
      end
    end

    if attempts < maxAttempts then
      hs.timer.doAfter(0.1, tryFloat)
    end
  end

  hs.timer.doAfter(0.2, tryFloat)
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