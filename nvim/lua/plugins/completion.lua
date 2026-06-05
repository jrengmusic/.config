-- Completion configuration
return {
  event = 'InsertEnter',
  dependencies = { 'hrsh7th/cmp-nvim-lsp' },
  setup = function()
    local cmp = require('cmp')
    local luasnip = require('luasnip')

    cmp.setup({
      completion = { completeopt = 'menu,menuone,noinsert' },
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
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
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local line = vim.api.nvim_get_current_line()
            local count = 0
            local pos = col + 1
            while line:sub(pos, pos):match('[%)%]%}%"\'%>`]') do
              count = count + 1
              pos = pos + 1
            end
            if count > 0 then
              local right = vim.api.nvim_replace_termcodes('<Right>', true, false, true)
              vim.api.nvim_feedkeys(string.rep(right, count), 'n', false)
            else
              fallback()
            end
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
        { name = 'luasnip', priority = 100 },
        {
          name = 'nvim_lsp',
          priority = 50,
          entry_filter = function(entry)
            -- Block clangd's auto-include insertions
            local item = entry:get_completion_item()
            if item.additionalTextEdits then
              for _, edit in ipairs(item.additionalTextEdits) do
                if edit.newText:match('#include') then
                  item.additionalTextEdits = nil
                  break
                end
              end
            end
            return true
          end,
        },
      },
    })
  end,
}
