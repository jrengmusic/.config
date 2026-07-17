-- Syntax highlighting configuration
return {
  branch = 'main',
  build = ':TSUpdate',
  main = 'nvim-treesitter.config',
  dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
  setup = function()
    require('syntax.highlight').setup()
    require('syntax.textobjects').setup()
  end,
}
