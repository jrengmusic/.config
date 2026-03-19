local fnKeys = hs.hotkey.modal.new({ "cmd", "shift", "alt" }, "F19")

local function systemKey(key)
	return function()
		hs.eventtap.event.newSystemKeyEvent(string.upper(key), true):post()
		hs.eventtap.event.newSystemKeyEvent(string.upper(key), false):post()
	end
end

-- Keyboard Shortcuts
local function bindKeyboardShortcuts()
	fnKeys:bind({}, "F1", systemKey("BRIGHTNESS_DOWN"))
	fnKeys:bind({}, "F2", systemKey("BRIGHTNESS_UP"))
	fnKeys:bind({}, "-", systemKey("ILLUMINATION_DOWN"))
	fnKeys:bind({}, "=", systemKey("ILLUMINATION_UP"))
	fnKeys:bind({}, "F7", systemKey("PREVIOUS"))
	fnKeys:bind({}, "F9", systemKey("NEXT"))
	fnKeys:bind({}, "F8", systemKey("PLAY"))
	fnKeys:bind({}, "F10", systemKey("MUTE"))
	fnKeys:bind({}, "F11", systemKey("SOUND_DOWN"))
	fnKeys:bind({}, "F12", systemKey("SOUND_UP"))
end

local fnMenuBar = hs.menubar.new()

local eventtap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
	if e:getFlags().fn then
		if fnToggle then
			fnKeys:enter()
		else
			fnKeys:exit()
		end
		fnToggle = not fnToggle
	end
end)

-- Intercept F11 key before OS
local function handleF11(event)
	local keyCode = event:getKeyCode()
	if keyCode == hs.keycodes.map["F11"] then
		if not fnToggle then
			systemKey("SOUND_DOWN")()
			return true -- Prevent OS from handling the key
		end
	end
	return false
end

local eventtapF11 = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, handleF11)

function fnKeys:entered()
	bindKeyboardShortcuts()
	eventtap:start()
	eventtapF11:start() -- Start capturing F11 key events
	fnMenuBar:setIcon("fn/inactive.png")
	hs.alert.closeAll(0, 0)
	hs.alert("CONTROL")
end

function fnKeys:exited()
	eventtapF11:stop() -- Stop capturing F11 key events
	fnMenuBar:setIcon("fn/active.png")
	hs.alert.closeAll(0, 0)
	hs.alert("FUNCTION")
end

local fnToggle = true
function setFnKeyDisplay(fnToggle)
	if fnToggle then
		fnMenuBar:setIcon("fn/active.png")
	else
		fnMenuBar:setIcon("fn/inactive.png")
	end
end

function fnkeyclicked()
	if fnToggle then
		fnKeys:enter()
	else
		fnKeys:exit()
	end
	fnToggle = not fnToggle
	setFnKeyDisplay(fnToggle)
end

if fnMenuBar then
	fnMenuBar:setClickCallback(fnkeyclicked)
	setFnKeyDisplay(fnToggle)
end

-- Initialize function keys as system key
fnKeys:enter()
