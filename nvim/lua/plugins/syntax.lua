-- Syntax highlighting configuration
return {
  branch = 'main',
  build = ':TSUpdate',
  main = 'nvim-treesitter.config',
  dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
  setup = function()
    vim.treesitter.language.register('cpp', 'objcpp')

    require('nvim-treesitter.config').setup({
      ensure_installed = {
        'bash', 'c', 'cpp', 'diff', 'html', 'lua', 'luadoc',
        'markdown', 'markdown_inline', 'query', 'regex', 'vim', 'vimdoc',
      },
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    })

    -- Treesitter textobjects setup
    require('nvim-treesitter-textobjects').setup({
      select = {
        lookahead = true,
      },
    })

    -- Textobject keymaps
    local select = require('nvim-treesitter-textobjects.select').select_textobject
    vim.keymap.set({ 'x', 'o' }, 'aF', function() select('@function.outer', 'textobjects') end, { desc = 'around function' })
    vim.keymap.set({ 'x', 'o' }, 'iF', function() select('@function.inner', 'textobjects') end, { desc = 'inside function' })
    vim.keymap.set({ 'x', 'o' }, 'aC', function() select('@class.outer', 'textobjects') end, { desc = 'around class' })
    vim.keymap.set({ 'x', 'o' }, 'iC', function() select('@class.inner', 'textobjects') end, { desc = 'inside class' })
    vim.keymap.set({ 'x', 'o' }, 'aL', function() select('@loop.outer', 'textobjects') end, { desc = 'around loop' })
    vim.keymap.set({ 'x', 'o' }, 'iL', function() select('@loop.inner', 'textobjects') end, { desc = 'inside loop' })
    vim.keymap.set({ 'x', 'o' }, 'aI', function() select('@conditional.outer', 'textobjects') end, { desc = 'around if/conditional' })
    vim.keymap.set({ 'x', 'o' }, 'iI', function() select('@conditional.inner', 'textobjects') end, { desc = 'inside if/conditional' })
  end,
}
