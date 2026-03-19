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
        actions = {
          explorer_add_resolve = function(picker, item)
            local current_dir = picker:dir()
            local project_root = vim.fn.getcwd()
            local project_name = vim.fn.fnamemodify(project_root, ':t')
            local escaped_project_name = project_name:gsub('%-', '%%-')
            local is_symlink_tree = current_dir:find('%.' .. escaped_project_name) ~= nil
            
            vim.ui.input({ prompt = 'Add file/dir (end with / for dir): ' }, function(name)
              if name == nil or name == '' then return end
              
              local is_dir = name:sub(-1) == '/'
              
              if is_symlink_tree then
                -- Step 1: Create file/dir in symlinked view first (for instant visibility)
                local symlink_path = current_dir .. '/' .. (is_dir and name:sub(1, -2) or name)
                
                if is_dir then
                  vim.fn.mkdir(symlink_path, 'p')
                else
                  vim.fn.mkdir(vim.fn.fnamemodify(symlink_path, ':h'), 'p')
                  vim.fn.writefile({}, symlink_path)
                end
                
                -- Step 2: Find real target directory from existing symlinks
                local sample_files = vim.fn.readdir(current_dir)
                local real_dir = nil
                
                for _, file in ipairs(sample_files) do
                  local full_path = current_dir .. '/' .. file
                  local link_target = vim.uv.fs_readlink(full_path)
                  if link_target and file ~= (is_dir and name:sub(1, -2) or name) then
                    real_dir = vim.fn.fnamemodify(link_target, ':h')
                    break
                  end
                end
                
                -- Step 3: Move to real location and create proper symlink
                if real_dir then
                  local real_path = real_dir .. '/' .. (is_dir and name:sub(1, -2) or name)
                  
                  if is_dir then
                    vim.fn.mkdir(real_path, 'p')
                    vim.fn.delete(symlink_path, 'rf')  -- Remove temp directory
                  else
                    vim.fn.mkdir(vim.fn.fnamemodify(real_path, ':h'), 'p')
                    vim.fn.rename(symlink_path, real_path)  -- Move file
                  end
                  
                  -- Create proper symlink
                  vim.fn.system({ 'ln', '-sf', real_path, symlink_path })
                  vim.notify('Created: ' .. real_path, vim.log.levels.INFO)
                else
                  vim.notify('Could not find real directory - created in symlink tree', vim.log.levels.WARN)
                end
              else
                -- Normal directory, create directly
                local target_path = current_dir .. '/' .. name
                if is_dir then
                  vim.fn.mkdir(target_path:sub(1, -2), 'p')
                else
                  vim.fn.mkdir(vim.fn.fnamemodify(target_path, ':h'), 'p')
                  vim.fn.writefile({}, target_path)
                end
                vim.notify('Created: ' .. target_path, vim.log.levels.INFO)
              end
              
              picker:find()
            end)
          end,
        },
        sources = {
          explorer = {
            win = {
              list = {
                keys = {
                  ['a'] = 'explorer_add_resolve',
                  ['<C-c>'] = 'close',
                },
              },
            },
          },
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
        formats = {
          header = function(item)
            local lines = vim.split(item.header, '\n')
            -- Top: dark red, Bottom: slightly lighter red with more orange
            local gradient_colors = {
              '#cd3131', -- top: dark red
              '#d23838', --
              '#d74040', --
              '#dc4848', --
              '#e15050', --
              '#e75858', --
              '#ec6060', --
              '#f16868', -- bottom: lighter red with more orange tint
            }
            -- Set up gradient highlights
            for i, color in ipairs(gradient_colors) do
              vim.api.nvim_set_hl(0, 'JrengGradient' .. i, { fg = color })
            end
            -- Return formatted text with gradient
            local result = {}
            for i, line in ipairs(lines) do
              if line ~= '' then
                table.insert(result, { line .. '\n', hl = 'JrengGradient' .. i, align = 'center' })
              end
            end
            return result
          end,
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
