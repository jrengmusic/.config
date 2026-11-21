-- LSP servers configuration
local M = {}

local LING_FILETYPES = { 'c', 'cpp', 'objc', 'objcpp', 'markdown', 'mermaid', 'json', 'css', 'xml', 'html' }
local PROJECT_EVENT = 'ProjectChanged'

local lingConfigurations = {}

local function lingRootDir(bufnr, on_dir)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local project = require('core.project').getProjectFor(name)
  if project then
    on_dir(project.manifest.root)
  else
    local git = vim.fs.root(bufnr, '.git')
    if git then
      on_dir(git)
    end
  end
end

local function getLingConfiguration(root)
  local project = require('core.project')
  local ast = project.getOrCreate(root)
  if ast then
    local key = project.getBuiltConfiguration(ast)
    local argument = key and ast.configurations[key] and ast.configurations[key].argument or ''
    return key, argument
  end
  return nil, ''
end

local function lingCmd(dispatchers, config)
  local root = config.root_dir
  local argv = { 'ling', 'project-info.md' }
  if root then
    local key, argument = getLingConfiguration(root)
    lingConfigurations[root] = key or false
    if argument ~= '' then
      argv[#argv + 1] = '--' .. argument
    end
  end
  return vim.lsp.rpc.start(argv, dispatchers, {
    cwd = root,
  })
end

function M.setup(capabilities)
  local servers = {
    ling = {
      root_dir = lingRootDir,
      cmd = lingCmd,
      filetypes = LING_FILETYPES,
    },
    lua_ls = {
      settings = {
        Lua = {
          completion = { callSnippet = 'Replace' },
        },
      },
    },
    pyright = {},
    cmake = {},
  }

  for name, cfg in pairs(servers) do
    vim.lsp.config(name, vim.tbl_deep_extend('force', cfg, { capabilities = capabilities }))
  end

  vim.lsp.enable(vim.tbl_keys(servers))

  vim.api.nvim_create_autocmd('User', {
    pattern = PROJECT_EVENT,
    group = vim.api.nvim_create_augroup('lsp-ling-project', { clear = true }),
    callback = function(event)
      local root = event.data and event.data.root
      if root then
        local key = getLingConfiguration(root)
        local nextKey = key or false
        for _, client in ipairs(vim.lsp.get_clients({ name = 'ling' })) do
          if client.config.root_dir == root and lingConfigurations[root] ~= nextKey then
            client:_restart(client.exit_timeout)
          end
        end
      end
    end,
  })
end

function M.setupAttachHandlers()
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)

      -- Register ling-specific commands
      if client and client.name == 'ling' then
        vim.api.nvim_buf_create_user_command(event.buf, 'LingSwitchSourceHeader', function()
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
      if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
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
