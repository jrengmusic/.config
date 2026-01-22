-- ============================================================================
-- NEOVIM CONFIGURATION
-- ============================================================================

-- Leader key (must be before plugins load)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

-- ============================================================================
-- CORE SETUP
-- ============================================================================

require('core.options').setup()
require('core.formatting').setup()
require('core.autocommands').setup()
require('core.keymaps').setup()

-- ============================================================================
-- BOOTSTRAP & PLUGINS
-- ============================================================================

require('core.bootstrap').setup()
local plug = require('core.plug')

require('lazy').setup({
  plug { repo = 'neovim/nvim-lspconfig', module = 'plugins.lsp' },
  plug { repo = 'hrsh7th/nvim-cmp', module = 'plugins.completion' },
  plug { repo = 'tpope/vim-sleuth', module = 'plugins.sleuth' },
  plug { repo = 'lewis6991/gitsigns.nvim', module = 'plugins.gitsigns' },
  plug { repo = 'brenoprata10/nvim-highlight-colors', module = 'plugins.highlight-colors' },
  plug { repo = 'nvim-lualine/lualine.nvim', module = 'plugins.ui' },
  plug { repo = 'folke/which-key.nvim', module = 'plugins.which-key' },
  plug { repo = 'nvim-tree/nvim-web-devicons', module = 'plugins.web-devicons' },
  plug { repo = 'echasnovski/mini.nvim', module = 'plugins.ui' },
  plug { repo = 'folke/noice.nvim', module = 'plugins.noice' },
  plug { repo = 'nvim-treesitter/nvim-treesitter', module = 'plugins.syntax' },
  plug { repo = 'folke/todo-comments.nvim', module = 'plugins.todo-comments' },
  plug { repo = 'stevearc/conform.nvim', module = 'plugins.formatting' },
  plug { repo = 'mfussenegger/nvim-dap', module = 'plugins.dap' },
  plug { repo = 'folke/snacks.nvim', module = 'plugins.picker' },
}, require('core.lazy_config').opts)

-- ============================================================================
-- COLORSCHEME
-- ============================================================================

vim.cmd('colorscheme gfx')

-- vim: ts=2 sts=2 sw=2 et
