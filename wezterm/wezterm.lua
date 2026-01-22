local wezterm = require("wezterm")
local config = {
	automatically_reload_config = true,
	window_close_confirmation = "AlwaysPrompt",
	window_decorations = "RESIZE",
	font = wezterm.font("Input Mono Narrow"),
	font_size = 13.0,
	initial_rows = 80,
	initial_cols = 100,
	-- Enable image rendering (for inline images, mermaid diagrams, etc.)
	enable_kitty_graphics = true,
	-- Better scrollback for long outputs
	scrollback_lines = 10000,
	background = {
		{
			source = {
				Color = "#0A1216", -- Brighter blue
			},
			width = "100%",
			height = "100%",
		},
	},
	colors = {
		foreground = "#B0DCE8", -- Much brighter blue/cyan
		tab_bar = {
			background = "rgba(0 0 0 0)",
			active_tab = {
				bg_color = "#0F1A20", -- Brighter blue
				fg_color = "#B0DCE8", -- Much brighter blue/cyan
			},
			inactive_tab = {
				bg_color = "#0A1216", -- Brighter blue
				fg_color = "#4A6575", -- Brighter blue
			},
			inactive_tab_hover = {
				bg_color = "#0A1216", -- Brighter blue
				fg_color = "#7AA5C0", -- Brighter blue
			},
			new_tab = {
				bg_color = "rgba(0 0 0 0)",
				fg_color = "#4A6575", -- Brighter blue
			},
			new_tab_hover = {
				bg_color = "rgba(0 0 0 0)",
				fg_color = "#B0DCE8", -- Much brighter blue/cyan
			},
		},
	},
	window_frame = {
		active_titlebar_bg = "rgba(0 0 0 0)",
	},
	skip_close_confirmation_for_processes_named = {
		"bash",
		"sh",
		"zsh",
		"fish",
		"tmux",
		"nu",
		"cmd.exe",
		"pwsh.exe",
		"powershell.exe",
		"nvim",
	},
	keys = {
		{
			key = "Enter",
			mods = "SHIFT",
			action = wezterm.action.SendString("\n"),
		},
		-- Split vertically (like :vsplit in vim) - creates left/right panes
		{
			key = "h",
			mods = "CMD|SHIFT",
			action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
		},
		-- Split horizontally (like :split in vim) - creates top/bottom panes
		{
			key = "v",
			mods = "CMD|SHIFT",
			action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
		},
		-- Switch between panes with CMD+h/j/k/l (vim-style)
		{
			key = "h",
			mods = "CMD",
			action = wezterm.action.ActivatePaneDirection("Left"),
		},
		{
			key = "j",
			mods = "CMD",
			action = wezterm.action.ActivatePaneDirection("Down"),
		},
		{
			key = "k",
			mods = "CMD",
			action = wezterm.action.ActivatePaneDirection("Up"),
		},
		{
			key = "l",
			mods = "CMD",
			action = wezterm.action.ActivatePaneDirection("Right"),
		},
		-- Close current pane
		{
			key = "w",
			mods = "CMD",
			action = wezterm.action.CloseCurrentPane({ confirm = false }),
		},
		-- Create 6 panes in a 2x3 grid layout using named event
		{
			key = "6",
			mods = "CMD|ALT",
			action = wezterm.action.EmitEvent("create_2x3_grid"),
		},
	},
}
-- Event handlers for custom actions
wezterm.on("create_2x3_grid", function(window, pane)
	-- Strategy: Create the full 2x3 grid with precisely equal panes using exact proportions

	-- First, create 2 equal rows by splitting the initial pane horizontally
	local top_pane = pane
	local bottom_pane = top_pane:split({
		direction = "Bottom",
		size = 0.5, -- 50% of available height for the bottom row
	})

	-- Now create 3 equal columns in the top row
	-- Method: Split the original into left 1/3 and right 2/3, then split right 2/3 into two 1/3 parts
	-- After the first split: the new pane (top_middle_pane) gets 33.33%, original (top_pane) keeps 66.67%
	local top_middle_pane = top_pane:split({
		direction = "Right",
		size = 0.3333, -- Creates right column: 33.33% of total width, top_pane keeps 66.67%
	})
	-- Now split the remaining 66.67% of top_pane into two equal parts: 33.33% each
	local top_right_pane = top_pane:split({
		direction = "Right",
		size = 0.5, -- Creates middle column: 50% of 66.67% = 33.33% of total width
	}) -- The remaining part of top_pane is the left column: also 33.33% of total width

	-- Now do the same for the bottom row to match the top
	local bottom_middle_pane = bottom_pane:split({
		direction = "Right",
		size = 0.3333, -- Creates bottom-right column: 33.33% of total width, bottom_pane keeps 66.67%
	})
	local bottom_right_pane = bottom_pane:split({ -- Split the remaining 66.67% of bottom_pane
		direction = "Right",
		size = 0.5, -- Creates bottom-middle column: 50% of 66.67% = 33.33% of total width
	}) -- The remaining part of bottom_pane is the bottom-left column: also 33.33% of total width
end)

return config
