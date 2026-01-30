-- GFX color scheme for Neovim
-- Converted from Xcode theme

local M = {}

M.setup = function()
  -- Reset highlights
  vim.cmd 'highlight clear'
  if vim.fn.exists 'syntax_on' then
    vim.cmd 'syntax reset'
  end

  vim.o.background = 'dark'
  vim.g.colors_name = 'gfx'

  -- Helper function to convert RGB float (0-1) to hex
  local function rgb_to_hex(r, g, b)
    return string.format('#%02x%02x%02x', math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
  end

  -- Define colors (converted from Xcode gfx.xccolortheme RGB float values)
  local colors = {
    -- Base colors
    bg = '#000000', -- DVTSourceTextBackground: 0 0 0
    fg = '#a8a8a8', -- xcode.syntax.plain: slightly darker
    cursor = '#ffffff', -- DVTSourceTextInsertionPointColor: 1 1 1

    -- UI colors
    current_line = '#1a1919', -- DVTSourceTextCurrentLineHighlightColor: 0.101961 0.0980392 0.0980392
    selection = '#4a4740', -- DVTSourceTextSelectionColor: 0.29228 0.280247 0.251752
    visual = '#4a4740',
    invisibles = '#333333', -- DVTSourceTextInvisiblesColor: 0.2 0.2 0.2

    -- Console colors
    console_bg = '#070d0e', -- DVTConsoleTextBackgroundColor: 0.027451 0.0509804 0.054902
    console_fg = '#a2e7e7', -- DVTConsoleDebuggerOutputTextColor: 0.635207 0.904387 0.904387
    console_prompt = '#00ffff', -- DVTConsoleDebuggerPromptTextColor: 0 1 1

    -- Syntax colors
    comment = '#6080c0', -- xcode.syntax.comment: 0.376471 0.501961 0.752941
    keyword = '#1919ff', -- xcode.syntax.keyword: 0.100197 0.100197 1
    string = '#ffc0c0', -- xcode.syntax.string: 1 0.752941 0.752941
    character = '#ffadaf', -- xcode.syntax.character: 1 0.679933 0.685268
    number = '#00ff00', -- xcode.syntax.number: 0 1 0
    boolean = '#00ff00',

    -- Types and declarations
    type = '#ff9080', -- xcode.syntax.identifier.type: brighter coral
    type_system = '#00a0ff', -- xcode.syntax.identifier.type.system: 0 0.626 1
    declaration = '#00c0ff', -- xcode.syntax.declaration.type: 0 0.752941 1
    class = '#00d0ff', -- xcode.syntax.identifier.class: brighter cyan
    class_system = '#00fffd', -- xcode.syntax.identifier.class.system: 0 1 0.991667

    -- Functions and identifiers
    func = '#80ffff', -- xcode.syntax.identifier.function: 0.5 1 1
    constant = '#ffff66', -- xcode.syntax.identifier.constant: 1 1 0.397946
    constant_system = '#00a0ff', -- xcode.syntax.identifier.constant.system: 0 0.626 1
    variable = '#00c6ff', -- xcode.syntax.identifier.variable: 0 0.776368 1
    variable_system = '#00a0ff', -- xcode.syntax.identifier.variable.system: 0 0.626 1

    -- Preprocessor and macros
    macro = '#9aff00', -- xcode.syntax.identifier.macro: 0.603793 1 0
    preprocessor = '#9aff00', -- xcode.syntax.preprocessor: 0.603793 1 0

    -- Markup and documentation
    markup_code = '#aa0d91', -- xcode.syntax.markup.code: 0.665 0.052 0.569
    url = '#4164ff', -- xcode.syntax.url: 0.255 0.392 1

    -- Regex
    regex = '#ff2b38', -- xcode.syntax.regex: 1 0.171 0.219
    regex_capture = '#23ff83', -- xcode.syntax.regex.capturename: 0.137 1 0.512
    regex_charname = '#00a0ff', -- xcode.syntax.regex.charname: 0 0.626 1
    regex_number = '#00ff00', -- xcode.syntax.regex.number: 0 1 0

    -- Diagnostics and scrollbar markers
    error = '#f74a4a', -- DVTScrollbarMarkerErrorColor: 0.968627 0.290196 0.290196
    warning = '#efb759', -- DVTScrollbarMarkerWarningColor: 0.937255 0.717647 0.34902
    info = '#a482ff', -- DVTScrollbarMarkerRuntimeIssueColor: 0.643137 0.509804 1
    hint = '#675fff', -- DVTScrollbarMarkerAnalyzerColor: 0.403922 0.372549 1
    breakpoint = '#4a4af7', -- DVTScrollbarMarkerBreakpointColor: 0.290196 0.290196 0.968627
    diff = '#8e8e8e', -- DVTScrollbarMarkerDiffColor: 0.556863 0.556863 0.556863

    -- Special
    special = '#ff2b38',
    attribute = '#2d44a0', -- xcode.syntax.attribute: 0.177359 0.265488 0.608972
    mark = '#6080c0', -- xcode.syntax.mark: 0.376471 0.501961 0.752941
  }

  -- Helper function to set highlights
  local function hi(group, opts)
    local cmd = 'highlight ' .. group
    if opts.fg then
      cmd = cmd .. ' guifg=' .. opts.fg
    end
    if opts.bg then
      cmd = cmd .. ' guibg=' .. opts.bg
    end
    if opts.gui then
      cmd = cmd .. ' gui=' .. opts.gui
    end
    if opts.sp then
      cmd = cmd .. ' guisp=' .. opts.sp
    end
    vim.cmd(cmd)
  end

  -- Helper function for linking highlights
  local function link(from, to)
    vim.cmd('highlight link ' .. from .. ' ' .. to)
  end

   -- Editor UI
   hi('Normal', { fg = colors.fg, bg = 'none' })
   hi('NormalFloat', { fg = colors.fg, bg = '#0a0a0a' })
   hi('Cursor', { fg = colors.bg, bg = colors.cursor })
   hi('CursorLine', { bg = '#0A1418' })
   hi('CursorLineNr', { fg = '#909090', gui = 'bold' })
   hi('LineNr', { fg = '#557575' })
   hi('SignColumn', { bg = 'none' })
   hi('EndOfBuffer', { fg = '#5F5F5F' })
   hi('Visual', { bg = '#2E4D53' })
  hi('VisualNOS', { bg = colors.visual })
  hi('Search', { fg = colors.bg, bg = colors.warning })
  hi('IncSearch', { fg = colors.bg, bg = colors.number })
  hi('MatchParen', { fg = colors.cursor, bg = colors.keyword, gui = 'bold' })

   -- Statusline
   hi('StatusLine', { fg = '#5F5F5F', bg = '#0A1317', gui = 'bold' })
   hi('StatusLineNC', { fg = '#557575', bg = '#0A1317' })
   hi('VertSplit', { fg = '#5B8181', bg = colors.bg })
   hi('WinSeparator', { fg = '#5B8181', bg = colors.bg })

  -- Tabline
  hi('TabLine', { fg = '#808080', bg = '#1a1a1a' })
  hi('TabLineFill', { bg = '#0d0d0d' })
  hi('TabLineSel', { fg = colors.fg, bg = colors.bg, gui = 'bold' })

  -- Popups
  hi('Pmenu', { fg = colors.fg, bg = '#1a1a1a' })
  hi('PmenuSel', { fg = colors.bg, bg = colors.func })
  hi('PmenuSbar', { bg = '#2a2a2a' })
  hi('PmenuThumb', { bg = '#4a4a4a' })

  -- Folds
  hi('Folded', { fg = colors.comment, bg = '#0d0d0d' })
  hi('FoldColumn', { fg = colors.comment, bg = colors.bg })

  -- Diff
  hi('DiffAdd', { bg = '#1a2a1a' })
  hi('DiffChange', { bg = '#1a1a2a' })
  hi('DiffDelete', { fg = colors.error, bg = '#2a1a1a' })
  hi('DiffText', { bg = '#2a2a4a', gui = 'bold' })

  -- Spelling
  hi('SpellBad', { sp = colors.error, gui = 'undercurl' })
  hi('SpellCap', { sp = colors.warning, gui = 'undercurl' })
  hi('SpellRare', { sp = colors.info, gui = 'undercurl' })
  hi('SpellLocal', { sp = colors.hint, gui = 'undercurl' })

  -- Diagnostics
  hi('DiagnosticError', { fg = colors.error })
  hi('DiagnosticWarn', { fg = colors.warning })
  hi('DiagnosticInfo', { fg = colors.info })
  hi('DiagnosticHint', { fg = colors.hint })
  hi('DiagnosticUnderlineError', { sp = colors.error, gui = 'undercurl' })
  hi('DiagnosticUnderlineWarn', { sp = colors.warning, gui = 'undercurl' })
  hi('DiagnosticUnderlineInfo', { sp = colors.info, gui = 'undercurl' })
  hi('DiagnosticUnderlineHint', { sp = colors.hint, gui = 'undercurl' })

   -- Syntax highlighting
   hi('Comment', { fg = colors.comment, gui = 'none' })
  hi('Constant', { fg = colors.constant })
  hi('String', { fg = colors.string })
  hi('Character', { fg = colors.character })
  hi('Number', { fg = colors.number })
  hi('Boolean', { fg = colors.keyword, gui = 'bold' })
  hi('Float', { fg = colors.number })

  hi('Identifier', { fg = colors.variable })
  hi('Function', { fg = colors.func })

  hi('Statement', { fg = colors.keyword, gui = 'bold' })
  hi('Conditional', { fg = colors.keyword, gui = 'bold' })
  hi('Repeat', { fg = colors.keyword, gui = 'bold' })
  hi('Label', { fg = colors.keyword, gui = 'bold' })
  hi('Operator', { fg = colors.keyword })
  hi('Keyword', { fg = colors.keyword, gui = 'bold' })
  hi('Exception', { fg = colors.keyword, gui = 'bold' })

  hi('PreProc', { fg = colors.macro })
  hi('Include', { fg = colors.macro })
  hi('Define', { fg = colors.macro })
  hi('Macro', { fg = colors.macro })
  hi('PreCondit', { fg = colors.macro })

  hi('Type', { fg = colors.type })
  hi('StorageClass', { fg = colors.keyword, gui = 'bold' })
  hi('Structure', { fg = colors.type })
  hi('Typedef', { fg = colors.type })

  hi('Special', { fg = '#a0a0a0' })
  hi('SpecialChar', { fg = colors.character })
  hi('Tag', { fg = colors.attribute })
  hi('Delimiter', { fg = '#a0a0a0' })
  hi('SpecialComment', { fg = colors.comment, gui = 'bold' })
  hi('Debug', { fg = colors.error })

  hi('Error', { fg = colors.error, gui = 'bold' })
  hi('ErrorMsg', { fg = colors.error, gui = 'bold' })
  hi('WarningMsg', { fg = colors.warning, gui = 'bold' })
  hi('Todo', { fg = colors.info, bg = colors.bg, gui = 'bold' })

  hi('Title', { fg = colors.class, gui = 'bold' })
  hi('Directory', { fg = colors.func })
   hi('Underlined', { fg = colors.url, gui = 'underline' })

   -- Snacks picker
   hi('SnacksPicker', { bg = '#0A1620', nocombine = true })
   hi('SnacksPickerBorder', { fg = 'none', bg = '#0A1620', nocombine = true })

   -- Treesitter highlights
  link('TSComment', 'Comment')
  link('TSConstant', 'Constant')
  link('TSString', 'String')
  link('TSCharacter', 'Character')
  link('TSNumber', 'Number')
  hi('@boolean', { fg = colors.keyword, gui = 'bold' })
  link('TSFloat', 'Float')

  link('TSFunction', 'Function')
  link('TSFunctionBuiltin', 'Function')
  link('TSMethod', 'Function')

  link('TSKeyword', 'Keyword')
  link('TSConditional', 'Conditional')
  link('TSRepeat', 'Repeat')
  link('TSLabel', 'Label')
  link('TSOperator', 'Operator')
  link('TSException', 'Exception')

  link('TSVariable', 'Identifier')
  hi('TSVariableBuiltin', { fg = colors.variable_system })

  hi('TSType', { fg = colors.type })
  hi('TSTypeBuiltin', { fg = colors.type_system })
  hi('TSConstructor', { fg = colors.func })

  hi('TSProperty', { fg = colors.variable })
  hi('TSField', { fg = colors.variable })
  hi('TSParameter', { fg = colors.variable })

  hi('@keyword.directive', { fg = colors.macro, gui = 'bold' })
  hi('@keyword.directive.cpp', { fg = colors.macro, gui = 'bold' })
  hi('@keyword.directive.define', { fg = colors.macro, gui = 'bold' })
  hi('@keyword.import', { fg = colors.macro, gui = 'bold' })
  hi('@keyword.conditional.preprocessor', { fg = colors.macro, gui = 'bold' })
  hi('@string.special.path', { fg = colors.macro })
  hi('@constant.macro', { fg = colors.macro })
  link('TSInclude', 'Include')
  link('TSDefine', 'Define')
  link('TSMacro', 'Macro')

  hi('TSTag', { fg = colors.attribute })
  hi('TSTagAttribute', { fg = colors.variable })
  link('TSTagDelimiter', 'Delimiter')

  -- Brackets, punctuation, operators (-> = : ; etc.)
  hi('TSPunctBracket', { fg = '#b0b0b0' })
  hi('TSPunctDelimiter', { fg = '#b0b0b0' })
  hi('@punctuation.bracket', { fg = '#b0b0b0' })
  hi('@punctuation.delimiter', { fg = '#b0b0b0' })
  hi('@operator', { fg = '#b0b0b0' })

  -- LSP semantic tokens
  hi('@lsp.type.class', { fg = colors.class })
  hi('@lsp.type.struct', { fg = colors.type })
  hi('@lsp.type.enum', { fg = colors.type })
  hi('@lsp.type.interface', { fg = colors.class_system })
  hi('@lsp.type.function', { fg = colors.func })
  hi('@lsp.type.method', { fg = colors.func })
  hi('@lsp.type.variable', { fg = colors.variable })
  hi('@lsp.type.parameter', { fg = colors.variable })
  hi('@lsp.type.property', { fg = colors.variable })
  hi('@lsp.type.macro', { fg = colors.macro, gui = 'bold' })

  -- Clangd semantic tokens for C++
  hi('@lsp.typemod.class.constructorOrDestructor', { fg = colors.func })
  hi('@lsp.mod.constructorOrDestructor', { fg = colors.func })

  -- Preprocessor: entire line lime
  hi('@preproc', { fg = colors.preprocessor })
  hi('@define', { fg = colors.preprocessor })
  hi('@lsp.type.dependent', { fg = colors.preprocessor })

  -- C++ primitive types as keywords (void, int, float, etc.)
  hi('@type.builtin', { fg = colors.keyword, gui = 'bold' })
  hi('@lsp.type.type', { fg = colors.keyword, gui = 'bold' })
  hi('@keyword.type', { fg = colors.keyword, gui = 'bold' })
  hi('@lsp.typemod.type.defaultLibrary', { fg = colors.keyword, gui = 'bold' })

  -- this, nullptr, true, false
  hi('@variable.builtin', { fg = colors.keyword, gui = 'bold' })
  hi('@constant.builtin', { fg = colors.keyword, gui = 'bold' })

  -- Git signs
  hi('GitSignsAdd', { fg = colors.number })
  hi('GitSignsChange', { fg = colors.warning })
  hi('GitSignsDelete', { fg = colors.error })

   -- Telescope
   hi('TelescopeBorder', { fg = '#4a4a4a' })
   hi('TelescopePromptBorder', { fg = colors.func })
   hi('TelescopeSelection', { bg = colors.current_line })
   hi('TelescopeMatching', { fg = colors.number, gui = 'bold' })

   -- Terminal error highlighting
   hi('TerminalCaret', { fg = '#FFA500', bold = true })  -- Orange for ^^^^^^^
   hi('TerminalLineNumber', { fg = '#00FF00', bold = true })  -- Green for line numbers
   hi('TerminalFilename', { fg = '#00FFFF', bold = false })  -- Cyan for filenames
end

-- Auto-load the theme
M.setup()

return M
