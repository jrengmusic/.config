-- Clangd LSP configuration
local M = {}

  function M.setup(capabilities)
    local servers = {
    clangd = {
      cmd = {
        vim.fn.stdpath('data') .. '/mason/bin/clangd',
        '--header-insertion=iwyu',
        '--clang-tidy',
        '--completion-style=detailed',
        '--header-insertion-decorators',
        '--query-driver=/usr/bin/c++,/usr/bin/clang++',
      },
    },
      lua_ls = {
        settings = {
          Lua = {
            completion = { callSnippet = 'Replace' },
          },
        },
      },
      gopls = {},
      zls = {},
      ts_ls = {},
      pyright = {},
      cmake = {},
    }

  local ensureInstalled = vim.tbl_keys(servers or {})
  vim.list_extend(ensureInstalled, { 'stylua', 'clangd', 'gopls', 'zls', 'prettier' })
  require('mason-tool-installer').setup({ ensure_installed = ensureInstalled })

  require('mason-lspconfig').setup({
    ensure_installed = vim.tbl_keys(servers),
    handlers = {
      function(serverName)
        local server = servers[serverName] or {}
        server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
        require('lspconfig')[serverName].setup(server)
      end,
    },
  })
end

function M.setupAttachHandlers()
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)

      -- Register clangd-specific commands (keymaps now in core/keymaps.lua)
      if client and client.name == 'clangd' then
        vim.api.nvim_buf_create_user_command(event.buf, 'ClangdSwitchSourceHeader', function()
          local params = { uri = vim.uri_from_bufnr(event.buf) }
          client:request('textDocument/switchSourceHeader', params, function(err, result)
            if result then
              vim.cmd('edit ' .. vim.uri_to_fname(result))
            end
          end, event.buf)
        end, { desc = 'Switch between header and source' })
      end

      -- Set up keymaps
      require('core.keymaps').setupLsp(event)

      -- Document highlight
      if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
        local highlightGroup = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })

        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = highlightGroup,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = highlightGroup,
          callback = vim.lsp.buf.clear_references,
        })

        vim.api.nvim_create_autocmd('LspDetach', {
          group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
          callback = function(detachEvent)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds({ group = 'lsp-highlight', buffer = detachEvent.buf })
          end,
        })
      end
    end,
  })
end

return M
