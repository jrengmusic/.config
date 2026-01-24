-- Test script to float an app manually
-- Usage: Just reload Hammerspoon config, then manually run from console:
--   require('test-float').test('END')

local M = {}

function M.test(appName)
  local debugLayout = require('debug-layout')
  
  print('=== Float Test ===')
  print('App name: ' .. appName)
  print('PaperWM loaded: ' .. tostring(PaperWM ~= nil))
  
  if not PaperWM then
    print('ERROR: PaperWM not loaded!')
    return
  end
  
  debugLayout.floatStandaloneApp(appName)
  
  print('=== Test Complete ===')
end

return M
