-- Koehler color scheme for Neovim
-- Converted from the classic Koehler Vim theme
-- Original maintainer: Ron Aaron <ron@ronware.org>

local M = {}

M.setup = function()
  -- Reset highlights
  vim.cmd 'highlight clear'
  if vim.fn.exists 'syntax_on' then
    vim.cmd 'syntax reset'
  end

  vim.o.background = 'dark'
  vim.g.colors_name = 'koehler'

  -- Define colors
  local colors = {
    white = '#ffffff',
    black = '#000000',
    darkcyan = '#008b8b',
    cyan = '#00ffff',
    darkred = '#cc0000',
    brown = '#cc8000',
    grey = '#808080',
    red = '#ff0000',
    darkgreen = '#2e8b57',
    seagreen = '#2e8b57',
    blue = '#0000ff',
    yellow = '#ffff00',
    lightblue = '#add8e6',
    green = '#00ff00',
    darkmagenta = '#8b008b',
    magenta = '#ff00ff',
    orange = '#ffa500',
    comment = '#80a0ff',
    constant = '#ffa0a0',
    identifier = '#40ffff',
    statement = '#ffff60',
    preproc = '#ff80ff',
    type = '#60ff60',
    darkgrey = '#555555',
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
    if opts.cterm then
      cmd = cmd .. ' cterm=' .. opts.cterm
    end
    if opts.ctermfg then
      cmd = cmd .. ' ctermfg=' .. opts.ctermfg
    end
    if opts.ctermbg then
      cmd = cmd .. ' ctermbg=' .. opts.ctermbg
    end
    if opts.term then
      cmd = cmd .. ' term=' .. opts.term
    end
    vim.cmd(cmd)
  end

  -- Helper function for linking highlights
  local function link(from, to)
    vim.cmd('highlight link ' .. from .. ' ' .. to)
  end

  -- Core highlights
  hi('Normal', { fg = colors.white, bg = colors.black })
  hi('Scrollbar', { fg = colors.darkcyan, bg = colors.cyan })
  hi('Menu', { fg = colors.black, bg = colors.cyan })
  hi('SpecialKey', { fg = colors.darkred, gui = 'bold', cterm = 'bold', ctermfg = 'darkred', term = 'bold' })
  hi('NonText', { fg = colors.darkred, gui = 'bold', cterm = 'bold', ctermfg = 'darkred', term = 'bold' })
  hi('Directory', { fg = colors.brown, gui = 'bold', cterm = 'bold', ctermfg = 'brown', term = 'bold' })
  hi('ErrorMsg', { fg = colors.white, bg = colors.red, cterm = 'bold', ctermfg = 'grey', ctermbg = 'red', term = 'standout' })
  hi('Search', { fg = colors.white, bg = colors.red, ctermfg = 'white', ctermbg = 'red', term = 'reverse' })
  hi('MoreMsg', { fg = colors.seagreen, gui = 'bold', cterm = 'bold', ctermfg = 'darkgreen', term = 'bold' })
  hi('ModeMsg', { fg = colors.white, bg = colors.blue, gui = 'bold', cterm = 'bold', term = 'bold' })
  hi('LineNr', { fg = colors.yellow, cterm = 'bold', ctermfg = 'darkcyan', term = 'underline' })
  hi('Question', { fg = colors.green, gui = 'bold', cterm = 'bold', ctermfg = 'darkgreen', term = 'standout' })
  hi('StatusLine', { fg = colors.blue, bg = colors.white, gui = 'bold', cterm = 'bold', ctermfg = 'lightblue', ctermbg = 'white', term = 'bold,reverse' })
  hi('StatusLineNC', { fg = colors.white, bg = colors.blue, ctermfg = 'white', ctermbg = 'lightblue', term = 'reverse' })
  hi('Title', { fg = colors.magenta, gui = 'bold', cterm = 'bold', ctermfg = 'darkmagenta', term = 'bold' })
  hi('Visual', { gui = 'reverse', cterm = 'reverse', term = 'reverse' })
  hi('WarningMsg', { fg = colors.red, cterm = 'bold', ctermfg = 'darkred', term = 'standout' })
  hi('Cursor', { fg = 'bg', bg = colors.green })
  hi('CursorLine', { bg = colors.darkgrey, cterm = 'underline', term = 'underline' })
  hi('CursorColumn', { bg = colors.darkgrey, cterm = 'underline', term = 'underline' })
  hi('MatchParen', { bg = colors.blue, ctermfg = 'blue', term = 'reverse' })

  -- Syntax highlighting
  hi('Comment', { fg = colors.comment, cterm = 'bold', ctermfg = 'cyan', term = 'bold' })
  hi('Constant', { fg = colors.constant, cterm = 'bold', ctermfg = 'magenta', term = 'underline' })
  hi('Special', { fg = colors.orange, cterm = 'bold', ctermfg = 'red', term = 'bold' })
  hi('Identifier', { fg = colors.identifier, ctermfg = 'brown', term = 'underline' })
  hi('Statement', { fg = colors.statement, gui = 'bold', cterm = 'bold', ctermfg = 'yellow', term = 'bold' })
  hi('PreProc', { fg = colors.preproc, ctermfg = 'darkmagenta', term = 'underline' })
  hi('Type', { fg = colors.type, gui = 'bold', cterm = 'bold', ctermfg = 'lightgreen', term = 'underline' })
  hi('Error', { fg = colors.red, bg = colors.black, ctermfg = 'darkcyan', ctermbg = 'black', term = 'reverse' })
  hi('Todo', { fg = colors.blue, bg = colors.yellow, ctermfg = 'black', ctermbg = 'darkcyan', term = 'standout' })
  hi('Underlined', { fg = colors.lightblue, gui = 'bold,underline', cterm = 'bold,underline', ctermfg = 'lightblue', term = 'underline' })
  hi('Ignore', { fg = colors.black, bg = colors.black, ctermfg = 'black', ctermbg = 'black' })
  hi('EndOfBuffer', { fg = colors.darkred, gui = 'bold', cterm = 'bold', ctermfg = 'darkred', term = 'bold' })

  -- Tab line
  hi('TabLine', { fg = colors.blue, bg = colors.white, gui = 'bold', cterm = 'bold', ctermfg = 'lightblue', ctermbg = 'white', term = 'bold,reverse' })
  hi('TabLineFill', { fg = colors.blue, bg = colors.white, gui = 'bold', cterm = 'bold', ctermfg = 'lightblue', ctermbg = 'white', term = 'bold,reverse' })
  hi('TabLineSel', { fg = colors.white, bg = colors.blue, ctermfg = 'white', ctermbg = 'lightblue', term = 'reverse' })

  -- Additional modern Neovim highlights
  hi('SignColumn', { bg = colors.black })
  hi('VertSplit', { fg = colors.blue, bg = colors.black })
  hi('Folded', { fg = colors.cyan, bg = '#1a1a1a' })
  hi('FoldColumn', { fg = colors.cyan, bg = colors.black })
  hi('Pmenu', { fg = colors.white, bg = '#1a1a1a' })
  hi('PmenuSel', { fg = colors.black, bg = colors.cyan })
  hi('PmenuSbar', { bg = '#2a2a2a' })
  hi('PmenuThumb', { bg = colors.grey })
  hi('CursorLineNr', { fg = colors.yellow, gui = 'bold', cterm = 'bold' })

  -- Links
  link('IncSearch', 'Visual')
  link('String', 'Constant')
  link('Character', 'Constant')
  link('Number', 'Constant')
  link('Boolean', 'Constant')
  link('Float', 'Number')
  link('Function', 'Identifier')
  link('Conditional', 'Statement')
  link('Repeat', 'Statement')
  link('Label', 'Statement')
  link('Operator', 'Statement')
  link('Keyword', 'Statement')
  link('Exception', 'Statement')
  link('Include', 'PreProc')
  link('Define', 'PreProc')
  link('Macro', 'PreProc')
  link('PreCondit', 'PreProc')
  link('StorageClass', 'Type')
  link('Structure', 'Type')
  link('Typedef', 'Type')
  link('Tag', 'Special')
  link('SpecialChar', 'Special')
  link('Delimiter', 'Special')
  link('SpecialComment', 'Special')
  link('Debug', 'Special')
end

-- Auto-load the theme
M.setup()

return M
