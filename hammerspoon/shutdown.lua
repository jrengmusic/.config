-- Create a modal hotkey object with an absurd triggering hotkey, since it will never be triggered from the keyboard
-- hotkeys = hs.hotkey.modal.new({"cmd", "shift", "alt"}, "F20")

-- Check macOS version
local osVersion = hs.host.operatingSystemVersion()
local isMontereyOrBelow = osVersion.major <= 12

-- Option–Command–Power button* or Option–Command–Media Eject
-- Put your Mac to sleep
hotkeys:bind({ "alt", "cmd" }, "F12", function()
	hs.caffeinate.systemSleep()
end)

-- Control–Command–Media Eject :
-- Quit all apps, then restart your Mac. If any open documents have unsaved changes, you will be asked whether you want to save them.
-- On Monterey and below: ctrl + alt + cmd + pagedown
-- On Ventura and later: ctrl + alt + cmd + F12
if isMontereyOrBelow then
	hotkeys:bind({ "ctrl", "alt", "cmd" }, "pagedown", function()
		hs.caffeinate.shutdownSystem()
	end)
else
	hotkeys:bind({ "ctrl", "alt", "cmd" }, "F12", function()
		hs.caffeinate.shutdownSystem()
	end)
end

-- Control–Command–Power button:*
-- Force your Mac to restart, without prompting to save any open and unsaved documents.
hotkeys:bind({ "ctrl", "cmd" }, "F12", function()
	hs.caffeinate.restartSystem()
end)

