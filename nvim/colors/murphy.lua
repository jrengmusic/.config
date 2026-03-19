-- Murphy color scheme for Neovim
-- Converted from the classic Murphy Vim theme
-- Original maintainer: Ron Aaron <ron@ronware.org>

local M = {}

M.setup = function()
  -- Reset highlights
  vim.cmd 'highlight clear'
  if vim.fn.exists 'syntax_on' then
    vim.cmd 'syntax reset'
  end

  vim.o.background = 'dark'
  vim.g.colors_name = 'murphy'

  -- Define colors
  local colors = {
    black = '#000000',
    white = '#ffffff',
    lightgreen = '#90ee90',
    orange = '#ffa500',
    lightred = '#ff6b6b',
    lightcyan = '#00ffff',
    lightblue = '#add8e6',
    wheat = '#f5deb3',
    blue = '#0000ff',
    magenta = '#ff00ff',
    yellow = '#ffff00',
    grey = '#808080',
    red = '#ff0000',
    orchid = '#da70d6',
    cyan = '#00ffff',
    darkred = '#8b0000',
    seagreen = '#2e8b57',
    pink = '#ffc0cb',
    darkblue = '#00008b',
    darkgrey = '#333333',
    darkgreen = '#006400',
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
    vim.cmd(cmd)
  end

  -- Core highlights
  hi('Normal', { fg = colors.lightgreen, bg = colors.black, ctermfg = 'lightgreen', ctermbg = 'Black' })
  hi('Comment', { fg = colors.orange, gui = 'bold', ctermfg = 'LightRed' })
  hi('Constant', { fg = colors.white, gui = 'NONE', ctermfg = 'LightGreen' })
  hi('Identifier', { fg = colors.lightcyan, ctermfg = 'LightCyan' })
  hi('Ignore', { fg = colors.black, ctermfg = 'black' })
  hi('PreProc', { fg = colors.wheat, ctermfg = 'LightBlue' })
  hi('Search', { fg = colors.white, bg = colors.blue })
  hi('Special', { fg = colors.magenta, gui = 'bold', ctermfg = 'LightRed' })
  hi('Statement', { fg = colors.yellow, gui = 'NONE', ctermfg = 'Yellow' })
  hi('Type', { fg = colors.grey, gui = 'none', ctermfg = 'LightGreen' })
  hi('Error', { fg = colors.white, bg = colors.red, ctermfg = 'White', ctermbg = 'Red' })
  hi('Todo', { fg = colors.blue, bg = colors.yellow, ctermfg = 'Black', ctermbg = 'Yellow' })

  -- UI elements
  hi('Cursor', { fg = colors.orchid, bg = 'fg' })
  hi('Directory', { fg = colors.cyan, gui = 'bold', ctermfg = 'LightCyan' })
  hi('ErrorMsg', { fg = colors.white, bg = colors.red, ctermfg = 'White', ctermbg = 'DarkRed' })
  hi('IncSearch', { gui = 'reverse', cterm = 'reverse' })
  hi('LineNr', { fg = colors.yellow, ctermfg = 'Yellow' })
  hi('ModeMsg', { gui = 'bold', cterm = 'bold' })
  hi('MoreMsg', { fg = colors.seagreen, gui = 'bold', ctermfg = 'LightGreen' })
  hi('NonText', { fg = colors.blue, gui = 'bold', ctermfg = 'Blue' })
  hi('Question', { fg = colors.cyan, gui = 'bold', ctermfg = 'LightGreen' })
  hi('SpecialKey', { fg = colors.cyan, gui = 'bold', ctermfg = 'LightBlue' })
  hi('StatusLine', { fg = colors.white, bg = colors.darkblue, gui = 'NONE', cterm = 'reverse' })
  hi('StatusLineNC', { fg = colors.white, bg = colors.darkgrey, gui = 'NONE', cterm = 'reverse' })
  hi('Title', { fg = colors.pink, gui = 'bold', ctermfg = 'LightMagenta' })
  hi('WarningMsg', { fg = colors.red, ctermfg = 'LightRed' })
  hi('Visual', { fg = colors.white, bg = colors.darkgreen, gui = 'NONE', cterm = 'reverse' })

  -- Additional modern Neovim highlights
  hi('CursorLine', { bg = '#1a1a1a' })
  hi('CursorLineNr', { fg = colors.yellow, gui = 'bold' })
  hi('SignColumn', { bg = colors.black })
  hi('VertSplit', { fg = colors.darkgrey, bg = colors.black })
  hi('Folded', { fg = colors.cyan, bg = '#1a1a1a' })
  hi('FoldColumn', { fg = colors.cyan, bg = colors.black })
  hi('Pmenu', { fg = colors.lightgreen, bg = '#1a1a1a' })
  hi('PmenuSel', { fg = colors.black, bg = colors.lightgreen })
  hi('PmenuSbar', { bg = '#2a2a2a' })
  hi('PmenuThumb', { bg = colors.grey })
end

-- Auto-load the theme
M.setup()

return M
