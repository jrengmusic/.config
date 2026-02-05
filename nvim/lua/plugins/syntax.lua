-- Syntax highlighting configuration
return {
  build = ':TSUpdate',
  main = 'nvim-treesitter.configs',
  dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
  setup = function()
    vim.treesitter.language.register('cpp', 'objcpp')

    require('nvim-treesitter.configs').setup({
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
    vim.keymap.set({ 'x', 'o' }, 'aS', function() select('@block.outer', 'textobjects') end, { desc = 'around scope/block' })
    vim.keymap.set({ 'x', 'o' }, 'iS', function() select('@block.inner', 'textobjects') end, { desc = 'inside scope/block' })
  end,
}
