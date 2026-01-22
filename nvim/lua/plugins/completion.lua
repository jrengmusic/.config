-- Completion configuration
return {
  event = 'InsertEnter',
  dependencies = { 'hrsh7th/cmp-nvim-lsp' },
  setup = function()
    local cmp = require('cmp')

    cmp.setup({
      completion = { completeopt = 'menu,menuone,noinsert' },
      mapping = cmp.mapping.preset.insert({
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
        ['<Tab>'] = cmp.mapping.select_next_item(),
        ['<S-Tab>'] = cmp.mapping.select_prev_item(),
        ['<C-Space>'] = cmp.mapping.complete({}),
      }),
      sources = {
        { name = 'nvim_lsp' },
      },
    })
  end,
}
