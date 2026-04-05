PaperWM = hs.loadSpoon("PaperWM")

-- Blacklist DAW windows from PaperWM tiling
local daws = {
	"REAPER",
	"DaVinci Resolve",
	"Fusion",
	"Logic Pro",
	"Pro Tools",
	"Cubase",
	"Studio One",
	"Ableton",
	"FL Studio",
	"UTM",
}

for _, daw in ipairs(daws) do
	PaperWM.window_filter = PaperWM.window_filter:setAppFilter(daw, false)
end

-- Reject END modal windows (Action List, etc.) while keeping the main window tiled
PaperWM.window_filter = PaperWM.window_filter:setAppFilter("END", {
	rejectTitles = { "Action List" }
})

PaperWM:bindHotkeys(PaperWM.default_hotkeys)

-- Menubar icon for modal state
local statusBar = hs.menubar.new()
statusBar:setIcon("paper-wm/inactive.png")

local modal = hs.hotkey.modal.new({ "ctrl" }, "space")

local actions = PaperWM.actions.actions()
modal:bind({}, "h", nil, actions.focus_left)
modal:bind({}, "j", nil, actions.focus_down)
modal:bind({}, "k", nil, actions.focus_up)
modal:bind({}, "l", nil, actions.focus_right)
modal:bind({ "shift" }, "h", nil, actions.swap_left)
modal:bind({ "shift" }, "j", nil, actions.slurp_in)
modal:bind({ "shift" }, "k", nil, actions.barf_out)
modal:bind({ "shift" }, "l", nil, actions.swap_right)
modal:bind({}, "1", nil, actions.focus_window_1)
modal:bind({}, "2", nil, actions.focus_window_2)
modal:bind({}, "3", nil, actions.focus_window_3)
modal:bind({}, "4", nil, actions.focus_window_4)
modal:bind({}, "5", nil, actions.focus_window_5)
modal:bind({}, "6", nil, actions.focus_window_6)
modal:bind({}, "7", nil, actions.focus_window_7)
modal:bind({}, "8", nil, actions.focus_window_8)
modal:bind({}, "9", nil, actions.focus_window_9)
modal:bind({}, "return", nil, actions.center_window)
modal:bind({}, "tab", nil, actions.full_width)
modal:bind({}, "=", nil, actions.increase_width)
modal:bind({}, "-", nil, actions.decrease_width)

modal:bind({}, "escape", function()
	statusBar:setIcon("paper-wm/inactive.png")
	modal:exit()
end)

function modal:entered()
	statusBar:setIcon("paper-wm/active.png")
end

-- Custom: Split focused + adjacent window 50/50 (others pushed off-screen)
local function splitEqual()
	local focused = hs.window.focusedWindow()
	if not focused then
		return
	end

	local space = hs.spaces.focusedSpace()
	local screen = focused:screen()
	local columns = PaperWM.state.windowList(space)

	if not columns or #columns < 2 then
		return
	end

	local focusedIndex = PaperWM.state.windowIndex(focused)
	if not focusedIndex then
		return
	end

	-- Find adjacent window (left first, then right)
	local adjacentCol = focusedIndex.col - 1
	local adjacent = PaperWM.state.windowList(space, adjacentCol, 1)
	if not adjacent then
		adjacentCol = focusedIndex.col + 1
		adjacent = PaperWM.state.windowList(space, adjacentCol, 1)
	end

	if not adjacent then
		-- Only 1 window or no adjacent: make full width
		PaperWM.windows.toggleWindowFullWidth()()
		return
	end

	-- Calculate 50% width
	local canvas = PaperWM.windows.getCanvas(screen)
	local gap = PaperWM.window_gap or 8
	local halfWidth = (canvas.w - gap) / 2

	-- Determine which is left, which is right
	local leftWin, rightWin
	local leftCol, rightCol
	if adjacentCol < focusedIndex.col then
		leftWin = adjacent
		rightWin = focused
		leftCol = adjacentCol
		rightCol = focusedIndex.col
	else
		leftWin = focused
		rightWin = adjacent
		leftCol = focusedIndex.col
		rightCol = adjacentCol
	end

	-- Position and resize both target windows
	local leftFrame = leftWin:frame()
	leftFrame.x = canvas.x
	leftFrame.w = halfWidth
	leftWin:setFrame(leftFrame)

	local rightFrame = rightWin:frame()
	rightFrame.x = canvas.x + halfWidth + gap
	rightFrame.w = halfWidth
	rightWin:setFrame(rightFrame)

	-- Retile to sync PaperWM state (pushes others off-screen)
	PaperWM.tiling.tileSpace(space, screen)
end

modal:bind({}, "0", nil, splitEqual)
modal:bind({}, "space", nil, actions.toggle_floating)

PaperWM:start()
