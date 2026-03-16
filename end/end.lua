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
--	                Ephemeral Nexus Display  v%versionString%
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
-- Colour format: "#AARRGGBB" where AA = alpha, RR/GG/BB = red/green/blue.
--   - "#RRGGBB" is also accepted (fully opaque, alpha = FF).
--   - "#RGB" shorthand is supported (each nibble expanded to two digits).
--   - "rgba(r, g, b, a)" functional notation (a is 0.0 - 1.0).
--
-- Key binding format: "modifier+key" (e.g. "cmd+c", "ctrl+shift+t").
--   - Modifiers: cmd, ctrl, alt, shift
--   - Prefix-mode keys (split, pane navigation) are single characters
--     activated after pressing the prefix key.
--
-- ============================================================================

END = {

	-- ========================================================================
	-- FONT
	-- ========================================================================

	font = {
		-- Font family name for the terminal grid.
		-- Must be a monospace font installed on the system.
		family = "Display Mono",

		-- Font size in points before zoom is applied (1 - 200).
		size = 11.0,

		-- Enable OpenType ligature substitution (e.g. -> becomes arrow).
		ligatures = true,

		-- Embolden glyphs for heavier strokes.
		-- Useful for thin fonts that are hard to read at small sizes.
		embolden = false,
	},

	-- ========================================================================
	-- CURSOR
	-- ========================================================================

	cursor = {
		-- Unicode character used as the cursor glyph.
		-- Default is the full block character U+2588.
		-- Only used when cursor shape is "glyph" (user-defined).
		-- Programs can override shape via DECSCUSR escape sequence
		-- unless cursor.force is true.
		char = "█",

		-- Enable cursor blinking.
		blink = true,

		-- Blink interval in milliseconds (100 - 5000).
		-- Full cycle = 2x this value (on for interval, off for interval).
		blink_interval = 500,

		-- Force user-configured cursor, ignoring DECSCUSR and OSC 12.
		-- When true, programs cannot change cursor shape or colour.
		force = false,
	},

	-- ========================================================================
	-- COLOURS
	-- ========================================================================
	--
	-- The 16 ANSI colours are used by terminal programs via SGR escape codes.
	-- Indices 0-7 are normal colours, 8-15 are bright variants.
	-- Format: "#AARRGGBB" (alpha + red + green + blue).
	--

	colours = {
		-- Default text foreground colour.
		foreground = "#FF4E8C93",

		-- Default background colour.
		-- Alpha channel controls terminal background opacity.
		background = "#E0090D12",

		-- Cursor colour.
		-- Can be overridden per-session by programs via OSC 12.
		cursor = "#FF4E8C93",

		-- Selection highlight colour.
		-- Semi-transparent recommended so text remains readable.
		selection = "#8000C8D8",

		-- ANSI colour 0: black
		black = "#FF090D12",

		-- ANSI colour 1: red
		red = "#FFFC704C",

		-- ANSI colour 2: green
		green = "#FFC5F0E9",

		-- ANSI colour 3: yellow
		yellow = "#FFF3F5C5",

		-- ANSI colour 4: blue
		blue = "#FF8CC9D9",

		-- ANSI colour 5: magenta
		magenta = "#FF519299",

		-- ANSI colour 6: cyan
		cyan = "#FF699DAA",

		-- ANSI colour 7: white
		white = "#FFFF0000",

		-- ANSI colour 8: bright black
		bright_black = "#FF33535B",

		-- ANSI colour 9: bright red
		bright_red = "#FFFC704C",

		-- ANSI colour 10: bright green
		bright_green = "#FFBAFFFD",

		-- ANSI colour 11: bright yellow
		bright_yellow = "#FFFEFFD2",

		-- ANSI colour 12: bright blue
		bright_blue = "#FF67DFEF",

		-- ANSI colour 13: bright magenta
		bright_magenta = "#FF01C2D2",

		-- ANSI colour 14: bright cyan
		bright_cyan = "#FF00C8D8",

		-- ANSI colour 15: bright white
		bright_white = "#FFBAFFFD",
	},

	-- ========================================================================
	-- WINDOW
	-- ========================================================================

	window = {
		-- Window title shown in the title bar and mission control.
		title = "END",

		-- Initial window width in pixels.
		width = 640,

		-- Initial window height in pixels.
		height = 480,

		-- Window background tint colour (no alpha, used for blur tint).
		colour = "#090D12",

		-- Window opacity (0.0 fully transparent - 1.0 fully opaque).
		opacity = 0.75,

		-- Background blur radius in pixels (0 = no blur).
		blur_radius = 32.0,

		-- Keep window above all other windows.
		always_on_top = false,

		-- Show native window buttons (close / minimise / maximise).
		buttons = false,

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
		size = 24.0,

		-- Active tab text colour.
		foreground = "#FF00C8D8",

		-- Inactive tab text colour.
		inactive = "#FF33535B",

		-- Tab bar position: "top", "bottom", "left", "right".
		position = "left",

		-- Tab separator line colour.
		line = "#FF2C4144",

		-- Active tab background colour.
		active = "#FF002B35",

		-- Active tab indicator colour.
		indicator = "#FF01C2D2",
	},

	-- ========================================================================
	-- MENU
	-- ========================================================================

	menu = {
		-- Popup menu background opacity (0.0 - 1.0).
		opacity = 0.6499999761581421,
	},

	-- ========================================================================
	-- OVERLAY
	-- ========================================================================

	overlay = {
		-- Overlay font family (used for status messages).
		family = "Display Mono",

		-- Overlay font size in points.
		size = 20.0,

		-- Overlay text colour.
		colour = "#4E8C93",
	},

	-- ========================================================================
	-- SHELL
	-- ========================================================================

	shell = {
		-- Shell program name or absolute path.
		-- Examples: "zsh", "bash", "fish", "/opt/homebrew/bin/fish"
		program = "C:\\msys64\\usr\\bin\\zsh.exe",

		-- Arguments passed to the shell program (space-separated string).
		-- Default: "-l" on Unix (login shell), "" on Windows.
		-- Set to "" to launch the shell with no arguments.
		args = "-l",
	},

	-- ========================================================================
	-- TERMINAL
	-- ========================================================================

	terminal = {
		-- Maximum number of scrollback lines retained in the ring buffer (100 - 1000000).
		scrollback_lines = 10000,

		-- Lines scrolled per mouse wheel tick and per Shift+PgUp/PgDn step (1 - 100).
		scroll_step = 5,

		-- Grid padding in logical pixels — space between the window edge and the
		-- terminal grid on each side.  Four values in CSS order:
		--   { top, right, bottom, left }
		-- All four values must be present.  Valid range: 0 - 200.
		-- Example: { 10, 10, 10, 10 } gives equal padding on all sides.
		--          { 4, 10, 10, 10 } gives a tighter top edge.
		padding = { 10, 10, 10, 10 },
	},

	-- ========================================================================
	-- PANE
	-- ========================================================================

	pane = {
		-- Pane divider bar colour.
		bar_colour = "#FF1B2A31",

		-- Pane divider bar colour when dragging or hovering.
		bar_highlight = "#FF4E8C93",
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
		copy = "ctrl+c",

		-- Paste from clipboard.
		paste = "ctrl+v",

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
		prefix_timeout = 1000,

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

		-- Open the action list (command palette).
		action_list = "?",

		-- Action list position: "top" or "bottom".
		action_list_position = "top",
	},

	-- ========================================================================
	-- POPUP DEFAULTS
	-- ========================================================================

	popup = {
		-- Default popup width as a fraction of the window width (0.1 - 1.0).
		-- Individual popup entries can override this.
		width = 0.6000000238418579,

		-- Default popup height as a fraction of the window height (0.1 - 1.0).
		-- Individual popup entries can override this.
		height = 0.5,

		-- Default popup position: "center".
		position = "center",
	},

	-- ========================================================================
	-- POPUPS
	-- ========================================================================
	--
	-- Modal popup terminals. Each entry spawns a terminal running a command
	-- in a glass overlay window. The popup blocks the main window until the
	-- process exits (quit the TUI, Ctrl+C a script, etc.).
	--
	-- Each entry is a named table. The table key is the unique identifier.
	--
	-- Fields:
	--   command  (string, required)  Shell command or executable to run.
	--   args     (string, optional)  Arguments passed to the command.
	--   cwd      (string, optional)  Working directory. Empty = inherit active terminal cwd.
	--   width    (number, optional)  Fraction of window width (0.1-1.0). Overrides popup.width.
	--   height   (number, optional)  Fraction of window height (0.1-1.0). Overrides popup.height.
	--   modal    (string, optional)  Modal key: prefix + key. Can include modifiers (e.g. "cmd+t").
	--   global   (string, optional)  Global key: direct shortcut, no prefix needed.
	--
	-- At least one of modal or global is required.
	-- Both can coexist on the same entry.
	--
	-- Examples:
	--
	-- popups = {
	--     tit = {
	--         command = "tit.exe",
	--         args = "",
	--         cwd = "",
	--         width = 0.8,
	--         height = 0.6,
	--         modal = "t",
	--     },
	--     lazygit = {
	--         command = "lazygit",
	--         width = 0.9,
	--         height = 0.9,
	--         modal = "g",
	--     },
	--     htop = {
	--         command = "htop",
	--         cwd = "~",
	--         width = 0.7,
	--         height = 0.5,
	--         modal = "p",
	--         global = "cmd+shift+p",
	--     },
	-- },
}
