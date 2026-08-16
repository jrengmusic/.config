-- Formatting configuration
return {
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>cf',
      function()
        require('conform').format({ async = true, lsp_format = 'fallback' })
      end,
      mode = '',
      desc = 'Format buffer',
    },
  },
  setup = function()
    require('conform').setup({
      notify_on_error = false,
      format_on_save = function(bufnr)
        local disableFiletypes = { c = true, cpp = true, objc = true, objcpp = true }
        local lspFormatOpt = disableFiletypes[vim.bo[bufnr].filetype] and 'never' or 'fallback'
        return { timeout_ms = 500, lsp_format = lspFormatOpt }
      end,
      formatters = {
        pandoc_markdown = {
          command = 'pandoc',
          args = {
            '-f',
            'markdown+grid_tables',
            '-t',
            'markdown-simple_tables-multiline_tables+pipe_tables+grid_tables',
            '--wrap=none',
          },
          stdin = true,
        },
      },
      formatters_by_ft = {
        lua = { 'stylua' },
        markdown = { 'pandoc_markdown' },
      },
    })
  end,
}
