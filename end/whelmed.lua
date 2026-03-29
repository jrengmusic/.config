-- =============================================================================
--
--                  ████                      ████                                       ████
--                  ████                      ████                                       ████
-- ████        ████ ██████████     ████████   ████ ██████████████     ████████     ██████████
-- ████  ████  ████ ████░░░░████ ████░░░░████ ████ ████░░████░░████ ████░░░░████ ████░░░░████
-- ████  ████  ████ ████    ████ ████████████ ████ ████  ████  ████ ████████████ ████    ████
-- ████████████████ ████    ████ ████░░░░░░░░ ████ ████  ████  ████ ████░░░░░░░░ ████    ████
-- ░░████░░░░████░░ ████    ████ ░░██████████ ████ ████  ████  ████ ░░██████████ ░░██████████
--   ░░░░    ░░░░   ░░░░    ░░░░   ░░░░░░░░░░ ░░░░ ░░░░  ░░░░  ░░░░   ░░░░░░░░░░   ░░░░░░░░░░
--
--          WYSIWYG Hybrid Encoder Lightweight Markdown/Mermaid Editor
--
-- =============================================================================
-- Configuration
-- =============================================================================
--
-- This file is auto-generated with default values on first launch.
-- Edit any value below to customise the Whelmed document viewer.
-- Invalid or missing values fall back to defaults silently.
-- Reload with Cmd+R (no restart needed).
--
-- Colour format: "RRGGBBAA" hex strings (red, green, blue, alpha).
--   - Alpha FF = fully opaque, 00 = fully transparent.
--   - Example: "B3F9F5FF" = frostbite teal, fully opaque.
--
-- =============================================================================

WHELMED = {

    -- =========================================================================
    -- TYPOGRAPHY
    -- =========================================================================
    --
    -- Body text uses a proportional font. Code blocks use a monospace font.
    -- Both ship embedded in the binary (Display / Display Mono).
    -- You can override with any font installed on the system.
    --

    -- Proportional body font family.
    font_family = "Display",

    -- Body font style (e.g. "Regular", "Medium", "Bold").
    font_style = "Medium",

    -- Base body size in points (8 - 72).
    font_size = 16.0,

    -- Monospace font family for code blocks.
    code_family = "Display Mono",

    -- Code font style (e.g. "Regular", "Medium", "Bold").
    code_style = "Medium",

    -- Code block font size in points (8 - 72).
    code_size = 12.0,

    -- Line height multiplier (0.8 - 3.0).
    line_height = 1.5,

    -- =========================================================================
    -- HEADING SIZES
    -- =========================================================================
    --
    -- Font sizes for each heading level, in points (8 - 72).
    -- Headings are rendered in bold using the body font family.
    --

    h1_size = 28.0,
    h2_size = 28.0,
    h3_size = 24.0,
    h4_size = 20.0,
    h5_size = 18.0,
    h6_size = 16.0,

    -- =========================================================================
    -- LAYOUT
    -- =========================================================================
    --
    -- Padding around the document content, in pixels.
    -- Order: top, right, bottom, left (CSS convention).
    --

    padding = { 10.0, 10.0, 10.0, 10.0 },

    -- =========================================================================
    -- COLOURS
    -- =========================================================================
    --
    -- All colours are RRGGBBAA hex strings.
    -- Document background, text colours, and heading colours.
    --

    -- Document background colour.
    background = "0D141CFF",

    -- Body text colour.
    body_colour = "B3F9F5FF",

    -- Link text colour.
    link_colour = "01C2D2FF",

    -- Heading colours. All headings share the same colour by default.
    -- Differentiation comes from size and weight, not colour.
    h1_colour = "D4C8A0FF",
    h2_colour = "D4C8A0FF",
    h3_colour = "D4C8A0FF",
    h4_colour = "D4C8A0FF",
    h5_colour = "D4C8A0FF",
    h6_colour = "D4C8A0FF",

    -- =========================================================================
    -- CODE BLOCKS
    -- =========================================================================
    --
    -- Fenced code blocks (```language ... ```) are rendered with syntax
    -- highlighting using the monospace font. Colours follow a vim-pablo-inspired
    -- scheme derived from the Oblivion TET palette.
    --

    -- Code block background colour.
    code_fence_background = "090D12FF",

    -- Inline code colour (e.g. `code` in body text).
    code_colour = "00D0FFFF",

    -- Syntax token colours.
    token_error        = "F74A4AFF",          -- error tokens
    token_comment      = "6080C0FF",        -- comments
    token_keyword      = "1919FFFF",        -- language keywords
    token_operator     = "B0B0B0FF",       -- operators (+, -, =, etc.)
    token_identifier   = "00C6FFFF",     -- variable and function names
    token_integer      = "00FF00FF",        -- integer literals
    token_float        = "00FF00FF",          -- float literals
    token_string       = "FFC0C0FF",         -- string literals
    token_bracket      = "80FFFFFF",        -- brackets ({, }, [, ], (, ))
    token_punctuation  = "FF9080FF",    -- punctuation (;, ,, .)
    token_preprocessor = "9AFF00FF",   -- preprocessor directives (#include)

    -- =========================================================================
    -- TABLE
    -- =========================================================================
    --
    -- Markdown tables are rendered with alternating row colours,
    -- configurable borders, and distinct header styling.
    --

    table_background        = "090D12FF",         -- table background
    table_header_background = "112130FF",  -- header row background
    table_row_alt           = "0D141CFF",            -- alternating row colour
    table_border_colour     = "2C4144FF",      -- table border colour
    table_header_text       = "BAFFFDFF",        -- header text colour
    table_cell_text         = "B3F9F5FF",          -- cell text colour

    -- =========================================================================
    -- PROGRESS BAR
    -- =========================================================================
    --
    -- Shown while the document is being parsed. A braille spinner and
    -- percentage label are overlaid on a translucent bar.
    --

    progress_background     = "1A1A1AFF",     -- bar background
    progress_foreground     = "4488CCFF",     -- bar fill colour
    progress_text_colour    = "CCCCCCFF",    -- percentage label colour
    progress_spinner_colour = "4488CCFF", -- braille spinner colour

    -- =========================================================================
    -- SCROLLBAR
    -- =========================================================================
    --
    -- Viewport scrollbar appearance.
    --

    scrollbar_thumb      = "2C4144FF",      -- scrollbar thumb (draggable)
    scrollbar_track      = "0D141CFF",      -- scrollbar track
    scrollbar_background = "0D141CFF", -- scrollbar background

    -- =========================================================================
    -- NAVIGATION
    -- =========================================================================
    --
    -- Vim-style keyboard navigation within the document.
    --

    scroll_down   = "%%scroll_down%%",    -- scroll down one step
    scroll_up     = "%%scroll_up%%",      -- scroll up one step
    scroll_top    = "%%scroll_top%%",     -- jump to top (gg)
    scroll_bottom = "%%scroll_bottom%%",  -- jump to bottom (G)
    scroll_step   = %%scroll_step%%,      -- pixels per scroll step
}
