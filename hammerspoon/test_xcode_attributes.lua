-- Test script to verify Xcode accessibility attribute support
-- Run this while Xcode is in focus with a text editor open

local ax = require("hs.axuielement")

print("\n=== Testing Xcode Accessibility Attributes ===\n")

-- Get the focused element
local systemElement = ax.systemWideElement()
local element = systemElement:attributeValue("AXFocusedUIElement")

if not element then
	print("ERROR: No focused element found. Make sure Xcode text editor is focused.")
	return
end

print("✓ Found focused element:", element)

-- Test 1: Check available parameterized attributes
print("\n--- Parameterized Attributes Available ---")
local paramAttrs = element:parameterizedAttributeNames()
if paramAttrs then
	for _, attr in ipairs(paramAttrs) do
		print("  • " .. attr)
	end
else
	print("  (none)")
end

-- Test 2: Check if specific attributes we need are available
print("\n--- Testing Required Attributes ---")

local hasLineForIndex = false
local hasRangeForLine = false

if paramAttrs then
	for _, attr in ipairs(paramAttrs) do
		if attr == "AXLineForIndex" then hasLineForIndex = true end
		if attr == "AXRangeForLine" then hasRangeForLine = true end
	end
end

print("AXLineForIndex:", hasLineForIndex and "✓ SUPPORTED" or "✗ NOT SUPPORTED")
print("AXRangeForLine:", hasRangeForLine and "✓ SUPPORTED" or "✗ NOT SUPPORTED")

-- Test 3: Check AXInsertionPointLineNumber
print("\n--- Testing AXInsertionPointLineNumber ---")
local insertionLineNumber = element:attributeValue("AXInsertionPointLineNumber")
if insertionLineNumber then
	print("✓ SUPPORTED - Current line number:", insertionLineNumber)
else
	print("✗ NOT SUPPORTED")
end

-- Test 4: Test AXLineForIndex with current cursor position
print("\n--- Testing AXLineForIndex ---")
local position = element:attributeValue("AXSelectedTextRange")
if position and hasLineForIndex then
	local success, lineNumber = pcall(function()
		return element:parameterizedAttributeValue("AXLineForIndex", position.location)
	end)

	if success and lineNumber then
		print("✓ SUCCESS - Character position", position.location, "is on line", lineNumber)
	else
		print("✗ FAILED - Error:", lineNumber)
	end
elseif not position then
	print("✗ Cannot test - no cursor position available")
else
	print("✗ Cannot test - attribute not supported")
end

-- Test 5: Test AXRangeForLine
print("\n--- Testing AXRangeForLine ---")
if hasRangeForLine and insertionLineNumber then
	local success, range = pcall(function()
		return element:parameterizedAttributeValue("AXRangeForLine", insertionLineNumber)
	end)

	if success and range then
		print("✓ SUCCESS - Line", insertionLineNumber, "range:", hs.inspect(range))
	else
		print("✗ FAILED - Error:", range)
	end
elseif not insertionLineNumber then
	print("✗ Cannot test - no line number available")
else
	print("✗ Cannot test - attribute not supported")
end

-- Test 6: Round-trip test (position → line → range)
print("\n--- Round-Trip Test ---")
if position and hasLineForIndex and hasRangeForLine then
	local success, result = pcall(function()
		-- Get line number from position
		local line = element:parameterizedAttributeValue("AXLineForIndex", position.location)
		-- Get range from line number
		local range = element:parameterizedAttributeValue("AXRangeForLine", line)
		-- Calculate column offset
		local columnOffset = position.location - range.location

		return {
			originalPos = position.location,
			lineNumber = line,
			lineRange = range,
			columnOffset = columnOffset
		}
	end)

	if success and result then
		print("✓ SUCCESS - Round-trip test passed:")
		print("  Original cursor position:", result.originalPos)
		print("  Line number:", result.lineNumber)
		print("  Line range:", hs.inspect(result.lineRange))
		print("  Column offset:", result.columnOffset)
		print("  Reconstructed position:", result.lineRange.location + result.columnOffset)
		print("  Match:", (result.lineRange.location + result.columnOffset) == result.originalPos and "✓" or "✗")
	else
		print("✗ FAILED - Error:", result)
	end
else
	print("✗ Cannot test - required attributes not supported")
end

print("\n=== Test Complete ===\n")

-- Summary
print("SUMMARY:")
if hasLineForIndex and hasRangeForLine then
	print("✓ Line-based positioning is FULLY SUPPORTED in Xcode!")
	print("  You can proceed with implementing the line-based approach.")
elseif insertionLineNumber then
	print("⚠ Partial support - AXInsertionPointLineNumber works but parameterized attributes don't")
	print("  Consider using a manual line-counting approach instead.")
else
	print("✗ Line-based positioning is NOT SUPPORTED in Xcode")
	print("  Will need to use alternative approaches (text parsing or relative positioning).")
end
