-- Formatting configuration
return {
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>cf',
      function()
        require('core.formatting').formatBufferByFiletype()
      end,
      mode = '',
      desc = 'Format buffer',
    },
  },
  setup = function()
    require('conform').setup({
      notify_on_error = false,
      format_on_save = function(bufnr)
        local disableFiletypes = { c = true, cpp = true, objc = true, objcpp = true, markdown = true }
        local lspFormatOpt = disableFiletypes[vim.bo[bufnr].filetype] and 'never' or 'fallback'
        return { timeout_ms = 500, lsp_format = lspFormatOpt }
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
      },
    })
  end,
}
