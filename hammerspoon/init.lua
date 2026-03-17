-- JRENG! (C) MMXV
---------------------------------------------------------------------------------------------

-- Load IPC module for CLI access (hs -c "command")
require("hs.ipc")

hs.alert.defaultStyle.radius = 18
hs.alert.defaultStyle.fillColor.alpha = 0.5
hs.alert.defaultStyle.strokeWidth = 0
hs.alert.defaultStyle.strokeColor.alpha = 0
hs.alert.defaultStyle.textSize = 30
hs.alert.defaultStyle.textStyle = { paragraphStyle = { alignment = "center" } }
hs.alert.defaultStyle.fadeInDuration = 0.1

-- Helper to show alert (closes previous alerts first)
local function alert(msg)
	hs.alert.closeAll()
	hs.alert.show(msg)
end

--------------------------------------------------------------------------------------
require("caps-esc")
require("caffeine")

-- Tiling disabled - using Amethyst for window management

require("fnkeys")
require("reload")
require("poems")
require("paper-wm")
require("debug-layout")

-- Create modal hotkey for shutdown commands (and app watcher below)
hotkeys = hs.hotkey.modal.new({ "cmd", "shift", "alt" }, "F20")

require("shutdown")
--------------------------------------------------------------------------------------

local wakeUpApps = {
	"REAPER",
	"Blender",
	"DaVinci Resolve",
	"Fusion",
}

-- Define a callback function to be called when application events happen
function applicationWatcherCallback(appName, eventType, appObject)
	for i = 1, #wakeUpApps, 1 do
		if appName == wakeUpApps[i] then
			if eventType == hs.application.watcher.activated then
				caffeineOn()
				hotkeys:exit()
			elseif eventType == hs.application.watcher.deactivated then
				caffeineOff()
				hotkeys:enter()
			end
		end
	end
end

-- Create and start the application event watcher
watcher = hs.application.watcher.new(applicationWatcherCallback)
watcher:start()
-- Activate the modal state
hotkeys:enter()
----------------------------------------------------------------
-- S P O O N S
----------------------------------------------------------------
---------------------------------------------------------------
dm = require("darkmode")
dm.addHandler(function(dm2)
	if dm2 then
		hs.settings.set("HSConsoleDarkModeKey", 1)
	else
		hs.settings.set("HSConsoleDarkModeKey", 0)
	end
end)

if dm.getDarkMode() then
	hs.settings.set("HSConsoleDarkModeKey", 1)
else
	hs.settings.set("HSConsoleDarkModeKey", 0)
end

-- Close console on launch (prevents it from auto-opening)
local consoleWin = hs.console.hswindow()
if consoleWin then
	consoleWin:close()
end
