-- LSP configuration
return {
  deps = 'lsp',
  setup = function()
    -- Ensure mason is set up first
    require('mason').setup()
    require('mason-lspconfig').setup()

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

    require('lsp.clangd').setupAttachHandlers()
    require('lsp.clangd').setup(capabilities)
    require('lsp.header-source').setup()
  end,
}
