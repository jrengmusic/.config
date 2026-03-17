local xcodeWatcher = nil
local ax = require("hs.axuielement")

-- Dummy modal for ESC key
local escKey = hs.hotkey.modal.new({ "ctrl", "cmd", "alt", "shift" }, "F19")

-- Function to check if the active application is Xcode using bundle ID
function checkActiveApp()
	local activeApp = hs.application.frontmostApplication()
	return activeApp and activeApp:bundleID() == "com.apple.dt.Xcode"
end

-- Function to get the focused UI element
function getFocusedElement()
	local systemElement = ax.systemWideElement()
	local focusedElement = systemElement:attributeValue("AXFocusedUIElement")
	print("Focused element:", focusedElement)
	return focusedElement
end

-- Function to get the scroll position in the focused UI element
function getScrollPosition()
	local element = getFocusedElement()
	if element then
		-- Get the visible character range
		local visibleRange = element:attributeValue("AXVisibleCharacterRange")
		if visibleRange then
			-- Also get the line number of the first visible character
			local text = element:attributeValue("AXValue")
			if text then
				local firstVisibleLine, _ = countLinesUpToPosition(text, visibleRange.location)
				print("Saved scroll position - visible range:", visibleRange.location, visibleRange.length, "firstLine:", firstVisibleLine)
				return {
					visibleRange = visibleRange,
					firstVisibleLine = firstVisibleLine
				}
			end
			-- Fallback without line number
			return {
				visibleRange = visibleRange,
				firstVisibleLine = nil
			}
		else
			print("WARNING: Element does not support AXVisibleCharacterRange")
		end
	end
	return nil
end

-- Function to restore the scroll position
-- This uses line-based positioning to restore both scroll and caret
function setScrollPositionAndCaret(scrollInfo, caretPosition)
	if not scrollInfo or not caretPosition then
		return false
	end

	local element = getFocusedElement()
	if not element then
		return false
	end

	-- Try line-based scroll restoration
	if scrollInfo.firstVisibleLine and caretPosition.lineNumber then
		local text = element:attributeValue("AXValue")
		if text then
			-- Calculate target positions
			local scrollTargetPos = findPositionFromLine(text, scrollInfo.firstVisibleLine, 0)
			local caretTargetPos = findPositionFromLine(text, caretPosition.lineNumber, caretPosition.columnOffset)

			-- First, move cursor to scroll target to force correct scrolling
			element:setAttributeValue("AXSelectedTextRange", {location = scrollTargetPos, length = 0})

			-- Immediately move cursor to actual position (no delay)
			element:setAttributeValue("AXSelectedTextRange", {location = caretTargetPos, length = 0})

			print("Restored scroll (line " .. scrollInfo.firstVisibleLine .. ") and caret (line " .. caretPosition.lineNumber .. ")")
			return true
		end
	end

	return false
end

-- Function to get all text from the focused UI element in Xcode
function getAllText()
	local element = getFocusedElement()
	if element then
		return element:attributeValue("AXValue")
	end
	return nil
end

-- Function to set text in the focused UI element in Xcode
function setText(text)
	local element = getFocusedElement()
	if element then
		-- Simply set the text once to avoid potential loops
		element:setAttributeValue("AXValue", text)
	end
end

-- Function to count lines in text up to a position
function countLinesUpToPosition(text, position)
	if not text or position == 0 then
		return 0, 0
	end

	local lineNumber = 0
	local lastNewlinePos = 0

	for i = 1, math.min(position, #text) do
		if text:sub(i, i) == '\n' then
			lineNumber = lineNumber + 1
			lastNewlinePos = i
		end
	end

	local columnOffset = position - lastNewlinePos
	return lineNumber, columnOffset
end

-- Function to get the caret position in the focused UI element
-- Returns both character position and line-based position
function getCaretPosition()
	local element = getFocusedElement()
	if element then
		local position = element:attributeValue("AXSelectedTextRange")
		if position then
			-- Get the text to calculate line number
			local text = element:attributeValue("AXValue")
			if text then
				local lineNumber, columnOffset = countLinesUpToPosition(text, position.location)
				print("Caret position before formatting: char=" .. position.location .. " line=" .. lineNumber .. " col=" .. columnOffset)
				return {
					characterPosition = position,
					lineNumber = lineNumber,
					columnOffset = columnOffset
				}
			end
			-- Fallback to character-only position
			print("Caret position before formatting:", position.location, position.length)
			return {
				characterPosition = position,
				lineNumber = nil,
				columnOffset = nil
			}
		end
	end
	print("Focused element does not support AXSelectedTextRange")
	return nil
end

-- Function to find character position from line number and column offset
function findPositionFromLine(text, targetLine, columnOffset)
	if not text then
		return 0
	end

	local currentLine = 0
	local lineStartPos = 0

	-- Find the start of the target line
	for i = 1, #text do
		if text:sub(i, i) == '\n' then
			currentLine = currentLine + 1
			if currentLine == targetLine then
				lineStartPos = i
				break
			end
		end
	end

	-- If we're on line 0 or found the target line
	if currentLine == targetLine or (targetLine == 0 and currentLine == 0) then
		local targetPos = lineStartPos + columnOffset

		-- Find the end of this line to avoid going past it
		local lineEndPos = #text
		for i = lineStartPos + 1, #text do
			if text:sub(i, i) == '\n' then
				lineEndPos = i - 1
				break
			end
		end

		-- Clamp to end of line
		targetPos = math.min(targetPos, lineEndPos)
		return targetPos
	end

	-- If target line doesn't exist (file got shorter), go to end
	return #text
end

-- Function to set the caret position in the focused UI element
function setCaretPosition(savedPosition)
	local element = getFocusedElement()
	if not element or not savedPosition then
		return
	end

	-- Try line-based restoration first
	if savedPosition.lineNumber and savedPosition.columnOffset then
		local text = element:attributeValue("AXValue")
		if text then
			local newCharPos = findPositionFromLine(text, savedPosition.lineNumber, savedPosition.columnOffset)
			local newPosition = {
				location = newCharPos,
				length = 0
			}
			element:setAttributeValue("AXSelectedTextRange", newPosition)
			print("Caret position after formatting: char=" .. newCharPos .. " (line=" .. savedPosition.lineNumber .. " col=" .. savedPosition.columnOffset .. ")")
			return
		end
	end

	-- Fallback to character-based restoration
	if savedPosition.characterPosition then
		element:setAttributeValue("AXSelectedTextRange", savedPosition.characterPosition)
		print("Caret position after formatting (fallback):", savedPosition.characterPosition.location, savedPosition.characterPosition.length)
	end
end

-- Modified formatTextWithClangFormat function
function formatTextWithClangFormat(text)
	local clangFormatPath = "/opt/local/libexec/llvm-21/bin/clang-format"
	local stylePath = "/Users/jreng/Documents/Poems/kuassa/___lib___/JUCE.clang-format"
	local tmpfile = os.tmpname()
	local file = io.open(tmpfile, "w")
	file:write(text)
	file:close()

	local command =
		string.format("%s --style=file:%s -assume-filename=dummy.mm %s", clangFormatPath, stylePath, tmpfile)
	print("Running clang-format command:", command)
	
	-- Test if the style file exists
	local styleFile = io.open(stylePath, "r")
	if not styleFile then
		print("ERROR: Style file does not exist at path:", stylePath)
		os.remove(tmpfile)
		return text
	end
	styleFile:close()
	
	-- Test if the clang-format binary exists
	local clangFormatFile = io.open(clangFormatPath, "r")
	if not clangFormatFile then
		print("ERROR: Clang-format binary does not exist at path:", clangFormatPath)
		os.remove(tmpfile)
		return text
	end
	clangFormatFile:close()

	local handle = io.popen(command, "r")
	if not handle then
		print("ERROR: Could not execute clang-format command")
		os.remove(tmpfile)
		return text
	end
	
	local formattedText = handle:read("*a")
	local success, exitReason, exitCode = handle:close()
	print("Command execution result - Success:", tostring(success), "Exit reason:", exitReason, "Exit code:", tostring(exitCode))
	print("Formatted text length:", #formattedText, "Original length:", #text)
	
	-- Debug: check if text was actually changed
	if formattedText and formattedText ~= "" and formattedText ~= text then
		print("SUCCESS: clang-format changed the text")
	else
		if formattedText == text then
			print("WARNING: clang-format did not change the text - it may already be formatted properly")
		elseif formattedText == "" or not formattedText then
			print("ERROR: clang-format returned empty result")
		end
	end
	
	os.remove(tmpfile)

	-- Fallback: if clang-format failed, keep the original text
	if not formattedText or formattedText == "" then
		print("ERROR: clang-format returned empty or nil result, returning original text")
		return text
	end
	return formattedText
end

-- Function to handle ESC key press
function handleEscKey()
	if checkActiveApp() then
		-- Prevent re-entry while formatting is in progress
		if isFormatting then
			print("Already formatting, ignoring ESC")
			return true
		end
		isFormatting = true

		-- Wrap everything in pcall for error handling
		local function resetAndSendEsc()
			-- Send ESC first while modal is still exited
			hs.eventtap.keyStroke({}, "escape")
			print("ESC key sent to Xcode")

			-- Then reset flag and re-enter modal after a delay
			hs.timer.doAfter(0.05, function()
				escKey:enter()
				isFormatting = false
				print("Modal re-entered after ESC")
			end)
		end

		escKey:exit() -- Exit dummy modal to prevent re-triggering

		local success, err = pcall(function()
			local originalText = getAllText()
			local caretPosition = getCaretPosition()
			local scrollPosition = getScrollPosition()

			if not originalText then
				print("Could not get text from editor")
				return
			end

			print("Original text length:", #originalText)
			-- First get the formatted text
			local formattedText = formatTextWithClangFormat(originalText)
			print("Formatted text length:", #formattedText)

			-- Check if text actually changed
			if formattedText == originalText then
				print("Text unchanged after formatting, skipping text update")
				resetAndSendEsc()
				return
			end

			-- Set the formatted text
			setText(formattedText)

			-- Wait a bit for setText to complete, then restore positions
			hs.timer.doAfter(0.03, function()
				local restoreSuccess, restoreErr = pcall(function()
					-- Try line-based restoration first (handles both scroll and caret)
					local success = false
					if scrollPosition and caretPosition then
						success = setScrollPositionAndCaret(scrollPosition, caretPosition)
					end

					-- Fallback: restore just the caret position if line-based failed
					if not success and caretPosition then
						setCaretPosition(caretPosition)
						print("Used fallback caret restoration")
					end
				end)

				if not restoreSuccess then
					print("Error restoring position:", restoreErr)
				end

				-- Always send ESC and reset, even if restoration failed
				-- Send ESC key to Xcode to switch to NORMAL mode
				hs.eventtap.keyStroke({}, "escape")
				print("ESC key sent to Xcode")

				-- Re-enter modal and reset flag
				hs.timer.doAfter(0.05, function()
					escKey:enter()
					isFormatting = false
					print("Formatting complete")
				end)
			end)
		end)

		if not success then
			print("Error in handleEscKey:", err)
			-- Ensure we always reset state on error
			resetAndSendEsc()
		end

		return true -- Prevent default behavior of ESC key
	end
	return false
end

-- Bind ESC key in the dummy modal
escKey:bind({}, "escape", function()
	return handleEscKey()
end)

-- Variable to track current state
local xcodeIsActive = false
local isFormatting = false

-- Watcher to monitor active application changes
xcodeWatcher = hs.application.watcher.new(function(name, event, app)
	local currentApp = hs.application.frontmostApplication()
	local isXcode = (currentApp:bundleID() == "com.apple.dt.Xcode")
	
	if event == hs.application.watcher.activated and isXcode then
		if not xcodeIsActive then
			xcodeIsActive = true
			escKey:enter() -- Enter dummy modal
			print("Xcode activated - ESC key interception enabled")
		end
	elseif event == hs.application.watcher.deactivated and name == "Xcode" then
		if xcodeIsActive then
			xcodeIsActive = false
			escKey:exit() -- Exit dummy modal
			print("Xcode deactivated - ESC key interception disabled")
		end
	end
end)

-- Also add a window focus check periodically to ensure we're always in sync
local function syncXcodeState()
	local currentApp = hs.application.frontmostApplication()
	local isXcode = (currentApp:bundleID() == "com.apple.dt.Xcode")
	
	if isXcode and not xcodeIsActive then
		xcodeIsActive = true
		escKey:enter()
		print("Xcode state synced - activated")
	elseif not isXcode and xcodeIsActive then
		xcodeIsActive = false
		escKey:exit()
		print("Xcode state synced - deactivated")
	end
end

-- Set up a timer to periodically sync the state
local syncTimer = hs.timer.new(0.3, syncXcodeState) -- Check every 0.3 seconds for faster response
syncTimer:start()

-- Add a window focus watcher for immediate response
local windowWatcher = hs.window.filter.new():subscribe(hs.window.filter.windowFocused, function(window, appName)
	syncXcodeState()
end)

-- Start watcher
xcodeWatcher:start()

-- Do an initial sync on load
syncXcodeState()
