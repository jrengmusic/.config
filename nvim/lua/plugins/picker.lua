-- Picker configuration
return {
  priority = 1000,
  lazy = false,
  setup = function()
    local dashboard = require('core.dashboard')
    local Snacks = require('snacks')
    Snacks.setup({
      picker = {
        enabled = true,
        sources = {
          snippets = {
            supports_live = false,
            preview = 'preview',
            format = function(item, picker)
              local name = Snacks.picker.util.align(item.name, picker.align_1 + 5)
              return {
                { name, item.ft == '' and 'Conceal' or 'DiagnosticWarn' },
                { item.description },
              }
            end,
            finder = function(_, ctx)
              local snippets = {}
              local luasnip = require('luasnip')
              for _, snip in ipairs(luasnip.get_snippets().all or {}) do
                snip.ft = ''
                table.insert(snippets, snip)
              end
              for _, snip in ipairs(luasnip.get_snippets(vim.bo.ft) or {}) do
                snip.ft = vim.bo.ft
                table.insert(snippets, snip)
              end
              local align_1 = 0
              for _, snip in pairs(snippets) do
                align_1 = math.max(align_1, #snip.name)
              end
              ctx.picker.align_1 = align_1
              local items = {}
              for _, snip in pairs(snippets) do
                local docstring = snip:get_docstring()
                if type(docstring) == 'table' then
                  docstring = table.concat(docstring)
                end
                local name = snip.name
                local description = table.concat(snip.description or {})
                description = name == description and '' or description
                table.insert(items, {
                  text = name .. ' ' .. description,
                  name = name,
                  description = description,
                  trigger = snip.trigger,
                  ft = snip.ft,
                  preview = {
                    ft = snip.ft,
                    text = docstring,
                  },
                })
              end
              return items
            end,
            confirm = function(picker, item)
              picker:close()
              local expand = {}
              require('luasnip').available(function(snippet)
                if snippet.trigger == item.trigger then
                  table.insert(expand, snippet)
                end
                return snippet
              end)
              if #expand > 0 then
                vim.cmd ':startinsert!'
                vim.defer_fn(function()
                  require('luasnip').snip_expand(expand[1])
                end, 50)
              else
                Snacks.notify.warn 'No snippet to expand'
              end
            end,
          },
        },
      },
      quickfile = { enabled = true },
      dashboard = {
        enabled = true,
        preset = {
          header = dashboard.header,
        },
        sections = dashboard.sections,
      },
      -- Explicitly disable unused features to suppress healthcheck warnings
      bigfile = { enabled = false },
      explorer = { enabled = true },
      image = { enabled = false },
      input = { enabled = false },
      lazygit = { enabled = false },
      notifier = { enabled = false },
      scope = { enabled = false },
      scroll = { enabled = false },
      statuscolumn = { enabled = false },
      words = { enabled = false },
    })
  end,
}
