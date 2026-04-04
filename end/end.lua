--	████████████████████  ████████████    ████  ████    ████    ████
--	████████████████████  ████████████    ████  ████    ████    ████
--	████░░░░░░░░░░░░████  ████░░░░████    ████  ░░░░    ░░░░    ████
--	████            ████  ████    ████    ████                  ████
--	████████████████████  ████    ████    ████  ████████████████████
--	████████████████████  ████    ████    ████  ████████████████████
--	████░░░░░░░░░░░░░░░░  ████    ████    ████  ████░░░░░░░░░░░░████
--	████                  ████    ████    ████  ████            ████
--	████████████████████  ████    ████████████  ████████████████████
--	████████████████████  ████    ████████████  ████████████████████
--	░░░░░░░░░░░░░░░░░░░░  ░░░░    ░░░░░░░░░░░░  ░░░░░░░░░░░░░░░░░░░░
--
--	                Ephemeral Nexus Display  v0.0.1
-- ============================================================================
-- Configuration
-- https://github.com/jrengmusic/end
-- ============================================================================
--
-- This file is auto-generated with default values on first launch.
-- Edit any value below to customise your terminal.
-- Invalid or missing values fall back to defaults silently.
-- Reload with Cmd+R (no restart needed).
--
-- Colour format: "#RRGGBB" (fully opaque) or "#RRGGBBAA" (with alpha).
--   - "#RGB" and "#RGBA" shorthand supported (e.g. "#F00" becomes "#FF0000").
--   - "rgba(r, g, b, a)" functional notation (a is 0.0 - 1.0).
--
-- Key binding format: "modifier+key" (e.g. "cmd+c", "ctrl+shift+t").
--   - Modifiers: cmd, ctrl, alt, shift
--   - Some keys use a two-step sequence: press the prefix key first, then the
--     action key. See the keys section below.
--
-- ============================================================================

END = {

	-- ========================================================================
	-- GPU
	-- ========================================================================
	--
	-- Rendering backend selection. Hot-reloadable (Cmd+R).
	--
	-- "auto"  — Use GPU if available, CPU fallback. (default)
	-- "true"  — Force GPU rendering. Falls back to CPU if unavailable.
	-- "false" — Force CPU rendering. No GPU used.
	--

	gpu = {
		acceleration = "auto",
	},

	-- ========================================================================
	-- FONT
	-- ========================================================================

	font = {
		-- Font used for terminal text.
		-- Must be a monospace font installed on the system.
		family = "Display Mono",

		-- Font size in points before zoom is applied (1 - 200).
		size = 12.0,

		-- Combine certain character sequences into symbols (e.g. -> becomes an arrow).
		ligatures = true,

		-- Make text appear bolder.
		-- Useful for thin fonts that are hard to read at small sizes.
		embolden = true,

		-- Line height multiplier applied to terminal cell height (0.5 - 3.0).
		-- 1.0 = no adjustment. Values above 1.0 increase spacing, below decrease it.
		line_height = 1.0,

		-- Cell width multiplier applied to terminal cell width (0.5 - 3.0).
		-- 1.0 = no adjustment. Values above 1.0 widen cells, below narrow them.
		cell_width = 1.0,
	},

	-- ========================================================================
	-- CURSOR
	-- ========================================================================

	cursor = {
		-- Character displayed as the cursor.
		-- Default is a solid block (the standard blinking rectangle).
		-- You can use any char, NF icons, including color emoji.
		-- Only used when cursor shape is "glyph" (user-defined).
		-- Programs (like vim or tmux) can change the cursor shape
		-- unless cursor.force is true.
		char = "█",

		-- Enable cursor blinking.
		blink = true,

		-- Blink interval in milliseconds (100 - 5000).
		-- Full cycle = 2x this value (on for interval, off for interval).
		blink_interval = 500.0,

		-- Lock the cursor to your configured shape and colour. Programs cannot change it.
		-- When true, programs cannot change cursor shape or colour.
		force = false,
	},

	-- ========================================================================
	-- COLOURS
	-- ========================================================================
	--
	-- The 16 standard terminal colours. Programs like ls, git, and vim use these.
	-- The first 8 are normal, the next 8 are brighter versions.
	-- Format: "#RRGGBB" (opaque) or "#RRGGBBAA" (with alpha).
	--

	colours = {
		-- Default text foreground colour.
		foreground = "#A1D6E5",

		-- Default background colour.
		-- The last two hex digits control background transparency (GPU only).
		-- CPU rendering always uses a fully opaque background.
		background = "#090D12FF",

		-- Cursor colour.
		-- Programs may change this colour while running.
		cursor = "#4E8C93",

		-- Selection highlight colour.
		-- Semi-transparent recommended so text remains readable.
		selection = "#00DDEE10",

		-- Selection-mode cursor colour.
		-- Shown instead of the normal cursor when selection mode is active.
		selection_cursor = "#00DDEE",

		-- Black
		black = "#090D12",

		-- Red
		red = "#FC704C",

		-- Green
		green = "#C5F0E9",

		-- Yellow
		yellow = "#F3F5C5",

		-- Blue
		blue = "#8CC9D9",

		-- Magenta
		magenta = "#519299",

		-- Cyan
		cyan = "#699DAA",

		-- White
		white = "#DDDDDD",

		-- Bright black
		bright_black = "#33535B",

		-- Bright red
		bright_red = "#FC704C",

		-- Bright green
		bright_green = "#BAFFFD",

		-- Bright yellow
		bright_yellow = "#FEFFD2",

		-- Bright blue
		bright_blue = "#67DFEF",

		-- Bright magenta
		bright_magenta = "#01C2D2",

		-- Bright cyan
		bright_cyan = "#00C8D8",

		-- Bright white
		bright_white = "#BAFFFD",

		-- Status bar full background colour.
		-- Default matches the active tab background (tab.active).
		status_bar = "#090D12",

		-- Status bar mode label background colour.
		-- Default matches the active tab indicator colour (tab.indicator).
		status_bar_label_bg = "#112130",

		-- Status bar mode label text colour.
		status_bar_label_fg = "#4E8C93",

		-- Status bar spinner colour.
		status_bar_spinner = "#00C8D8",

		-- Status bar font family.
		status_bar_font_family = "Display Mono",

		-- Status bar font size in points.
		status_bar_font_size = 12.0,

		-- Status bar font style.
		status_bar_font_style = "Bold",

		-- Open File mode hint label background colour.
		-- Shown as the badge background behind single- or double-letter hint keys.
		hint_label_bg = "#00FFFF",

		-- Open File mode hint label foreground (text) colour.
		hint_label_fg = "#111111",
	},

	-- ========================================================================
	-- WINDOW
	-- ========================================================================

	window = {
		-- Window title shown in the title bar and mission control.
		title = "END",

		-- Initial window width in pixels.
		width = 640.0,

		-- Initial window height in pixels.
		height = 480.0,

		-- Tint colour for the window background. Most visible with blur enabled.
		colour = "#090D12",

		-- Window opacity (0.0 fully transparent - 1.0 fully opaque).
		-- GPU only. Has no effect with CPU rendering.
		-- macOS and Windows 10 only. No effect on Windows 11.
		opacity = 0.75,

		-- Background blur radius in pixels (0 = no blur).
		-- GPU only. Has no effect with CPU rendering.
		-- macOS: controls blur intensity.
		-- Windows 10: blur is on but intensity is set by the system.
		-- Windows 11: uses the system glass effect. This setting has no effect.
		blur_radius = 32.0,

		-- Keep window above all other windows.
		always_on_top = false,

		-- Show native window buttons (close / minimise / maximise).
		buttons = false,

		-- Force DWM visual effects on Windows 11 virtual machines.
		-- When true, injects the ForceEffectMode registry key to enable
		-- rounded window corners that DWM normally disables inside VMs.
		-- Only takes effect on Windows 11 running on a software renderer (VM).
		-- Requires elevated privileges (Run as Administrator).
		-- Reload config and restart END to apply.
		-- No effect on macOS, Linux, or physical Windows machines.
		force_dwm = true,

		-- Zoom multiplier (1.0 - 4.0).
		-- Scales the terminal grid and font proportionally.
		zoom = 1.0,
	},

	-- ========================================================================
	-- TAB BAR
	-- ========================================================================

	tab = {
		-- Tab bar font family.
		family = "Display Mono",

		-- Tab bar font size in points.
		size = 12.0,

		-- Active tab text colour.
		foreground = "#00C8D8",

		-- Inactive tab text colour.
		inactive = "#33535B",

		-- Tab bar position: "top", "bottom", "left", "right".
		position = "left",

		-- Tab separator line colour.
		line = "#2C4144",

		-- Active tab background colour.
		active = "#002B35",

		-- Active tab indicator colour.
		indicator = "#01C2D2",
	},

	-- ========================================================================
	-- MENU
	-- ========================================================================

	menu = {
		-- Popup menu background opacity (0.0 - 1.0).
		opacity = 0.65,
	},

	-- ========================================================================
	-- OVERLAY
	-- ========================================================================

	overlay = {
		-- Overlay font family (used for status messages).
		family = "Display Mono",

		-- Overlay font size in points.
		size = 14.0,

		-- Overlay text colour.
		colour = "#4E8C93",
	},

	-- ========================================================================
	-- SHELL
	-- ========================================================================

	shell = {
		-- Shell program name or absolute path.
		program = "zsh",

		-- Arguments passed to the shell program.
		args = "-l",

		-- Enable automatic shell integration.
		-- When true, END creates shell hook scripts in ~/.config/end/
		-- and injects them on shell startup. This enables:
		--   - Clickable file links in command output
		--   - Output block detection for the Open File feature
		-- Supported shells: zsh, bash, fish.
		-- Set to false to disable and remove integration scripts.
		integration = true,
	},

	-- ========================================================================
	-- TERMINAL
	-- ========================================================================

	terminal = {
		-- Maximum number of lines you can scroll back through (100 - 1000000).
		scrollback_lines = 10000.0,

		-- Lines scrolled per mouse wheel tick and per Shift+PgUp/PgDn step (1 - 100).
		scroll_step = 5.0,

		-- Space between the window edge and the terminal text, in pixels. Four values:
		--   { top, right, bottom, left }
		-- All four values must be present.  Valid range: 0 - 200.
		-- Example: { 10, 10, 10, 10 } gives equal padding on all sides.
		--          { 4, 10, 10, 10 } gives a tighter top edge.
		padding = { 10.0, 10.0, 10.0, 10.0 },

		-- Separator for multiple dropped file paths.
		-- "space" joins paths with spaces (shell convention).
		-- "newline" joins paths with newlines.
		drop_multifiles = "space",

		-- Wrap dropped file paths in quotes so spaces and special characters work correctly.
		-- true: paths with special characters are quoted for the active shell.
		-- false: paths are pasted raw (for TUI apps that handle paths directly).
		drop_quoted = true,
	},

	-- ========================================================================
	-- PANE
	-- ========================================================================

	pane = {
		-- Pane divider bar colour.
		bar_colour = "#1B2A31",

		-- Pane divider bar colour when dragging or hovering.
		bar_highlight = "#4E8C93",
	},

	-- ========================================================================
	-- KEY BINDINGS
	-- ========================================================================
	--
	-- Direct key bindings use "modifier+key" format (e.g. "cmd+c").
	-- Prefix-mode keys are single characters pressed AFTER the prefix key.
	-- Prefix mode: press prefix key, then within timeout press the action key.
	--

	keys = {
		-- Copy selection to clipboard.
		copy = "cmd+c",

		-- Paste from clipboard.
		paste = "cmd+v",

		-- Quit application.
		quit = "cmd+q",

		-- Close active pane, then tab, then window.
		close_tab = "cmd+w",

		-- Reload configuration file.
		reload = "cmd+r",

		-- Increase zoom level.
		zoom_in = "cmd+=",

		-- Decrease zoom level.
		zoom_out = "cmd+-",

		-- Reset zoom to 1.0.
		zoom_reset = "cmd+0",

		-- Open a new window.
		new_window = "cmd+n",

		-- Open a new tab.
		new_tab = "cmd+t",

		-- Switch to previous tab.
		prev_tab = "cmd+[",

		-- Switch to next tab.
		next_tab = "cmd+]",

		-- Split pane horizontally (left/right). Prefix-mode key.
		split_horizontal = "\\",

		-- Split pane vertically (top/bottom). Prefix-mode key.
		split_vertical = "-",

		-- Prefix key for modal pane commands.
		-- Press this key first, then press a pane action key within the timeout.
		prefix = "`",

		-- Prefix key timeout in milliseconds (100 - 5000).
		-- How long to wait for a pane action key after pressing prefix.
		prefix_timeout = 1000.0,

		-- Focus pane to the left. Prefix-mode key.
		pane_left = "h",

		-- Focus pane below. Prefix-mode key.
		pane_down = "j",

		-- Focus pane above. Prefix-mode key.
		pane_up = "k",

		-- Focus pane to the right. Prefix-mode key.
		pane_right = "l",

		-- Insert a literal newline (LF) instead of carriage return.
		newline = "shift+return",

		-- Enter text selection mode. Prefix-mode key.
		enter_selection = "[",

		-- Enter open-file mode (hyperlink hint labels). Prefix-mode key.
		enter_open_file = "o",

		-- ---- Selection mode ----

		-- Move cursor up in selection mode.
		selection_up = "k",

		-- Move cursor down in selection mode.
		selection_down = "j",

		-- Move cursor left in selection mode.
		selection_left = "h",

		-- Move cursor right in selection mode.
		selection_right = "l",

		-- Toggle character-wise visual selection.
		selection_visual = "v",

		-- Toggle line-wise visual selection.
		selection_visual_line = "shift+v",

		-- Toggle block visual selection.
		selection_visual_block = "ctrl+v",

		-- Yank (copy) the current selection and exit selection mode.
		selection_copy = "y",

		-- Jump to top of buffer (press twice: gg).
		selection_top = "g",

		-- Jump to bottom of buffer.
		selection_bottom = "shift+g",

		-- Jump to start of current line.
		selection_line_start = "0",

		-- Jump to end of current line.
		selection_line_end = "$",

		-- Exit selection mode.
		selection_exit = "escape",

		-- Open the action list (command palette).
		action_list = "?",

		-- Action list position: "top" or "bottom".
		action_list_position = "top",

		-- Status bar position: "top" or "bottom".
		status_bar_position = "bottom",
	},

	-- ========================================================================
	-- POPUP DEFAULTS
	-- ========================================================================

	popup = {
		-- Default popup width in columns.
		-- Individual popup entries can override this.
		cols = 70,

		-- Default popup height in rows.
		-- Individual popup entries can override this.
		rows = 20,

		-- Default popup position: "center".
		position = "center",

		-- Popup border colour.
		border_colour = "#4E8C93",

		-- Popup border stroke width in pixels (0 = no border).
		border_width = 1.0,
	},

	-- ========================================================================
	-- HYPERLINKS
	-- ========================================================================

	hyperlinks = {
		-- Editor command for opening files from hyperlinks and Open File mode.
		-- The command receives the file path as its first argument.
		-- Example: "nvim", "vim", "nano", "/usr/local/bin/hx"
		editor = "nvim",

		-- Per-extension handler commands (override the editor for specific file types).
		-- Keys are file extensions (with leading dot), values are shell commands.
		-- handlers = {
		--     [".png"] = "open",
		--     [".pdf"] = "open -a Preview",
		-- },

		-- Extra clickable extensions beyond the built-in set.
		-- Use this for frameworks or custom extensions not in the built-in list.
		-- These fall back to the editor command.
		-- extensions = { ".vue", ".svelte", ".astro" },
	},

	-- ========================================================================
	-- POPUPS
	-- ========================================================================
	--
	-- Modal popup terminals. Each entry spawns a terminal running a command
	-- in a floating panel on top of the terminal. The popup blocks the main
	-- window until the process exits (quit the TUI, Ctrl+C a script, etc.).
	--
	-- Each entry is a named table. The table key is the unique identifier.
	--
	-- Fields:
	--   command  (string, required)  Shell command or executable to run.
	--   args     (string, optional)  Arguments passed to the command.
	--   cwd      (string, optional)  Working directory. Empty = inherit active terminal cwd.
	--   cols     (number, optional)  Width in columns. Overrides popup.cols.
	--   rows     (number, optional)  Height in rows. Overrides popup.rows.
	--   modal    (string, optional)  Key pressed after the prefix key (e.g. "t").
	--   global   (string, optional)  Global key: direct shortcut, no prefix needed.
	--
	-- At least one of modal or global is required.
	-- Both can coexist on the same entry.
	--
	-- Examples:
	--
	popups = {
		tit = {
			command = "tit",
			args = "",
			cwd = "",
			cols = 70,
			rows = 30,
			modal = "t",
		},
	--	btop = {
	--		command = "htop",
	--		cwd = "~",
	--		cols = 80,
	--		rows = 24,
	--		modal = "p",
	--		global = "cmd+shift+p",
	--     },
	},
}
