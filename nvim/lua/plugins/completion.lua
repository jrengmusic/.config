-- Completion configuration
return {
  event = 'InsertEnter',
  dependencies = { 'hrsh7th/cmp-nvim-lsp' },
  setup = function()
    local cmp = require('cmp')
    local luasnip = require('luasnip')

    cmp.setup({
      completion = { completeopt = 'menu,menuone,noinsert' },
      mapping = cmp.mapping.preset.insert({
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<CR>'] = cmp.mapping.confirm({ select = true, behavior = cmp.ConfirmBehavior.Insert }),
        ['<Tab>'] = cmp.mapping(function(fallback)
          if luasnip.expand_or_locally_jumpable() then
            luasnip.expand_or_jump()
          elseif cmp.visible() then
            cmp.select_next_item()
          else
            fallback()
          end
        end, { 'i', 's' }),
        ['<S-Tab>'] = cmp.mapping(function(fallback)
          if luasnip.jumpable(-1) then
            luasnip.jump(-1)
          elseif cmp.visible() then
            cmp.select_prev_item()
          else
            fallback()
          end
        end, { 'i', 's' }),
        ['<C-Space>'] = cmp.mapping.complete({}),
      }),
      sources = {
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
      },
    })
  end,
}
