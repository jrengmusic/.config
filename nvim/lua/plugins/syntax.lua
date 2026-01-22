-- Syntax highlighting configuration
return {
  build = ':TSUpdate',
  main = 'nvim-treesitter.configs',
  setup = function()
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
  end,
}
