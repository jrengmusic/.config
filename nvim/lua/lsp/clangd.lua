-- Clangd LSP configuration
local M = {}

-- The default root_markers = {'.clangd', '.git'} treats every git repo as
-- its own LSP root — correct for an independent project, wrong for a
-- framework repo compiled only by the project that builds it. Left alone,
-- that spawns a second clangd instance background-indexing the same
-- compile_commands.json in parallel with the first, doubling indexing time
-- and CPU contention. The project state (core/project.lua) answers this:
-- a buffer under a loaded project or its user-module tree roots at that
-- project, so one clangd instance answers for both trees. Anything else
-- roots at its git repo.
local function clangdRootDir(bufnr, on_dir)
  local project = require('core.project').getProjectFor(vim.api.nvim_buf_get_name(bufnr))
  if project then
    on_dir(project.manifest.root)
  else
    on_dir(vim.fs.root(bufnr, '.git'))
  end
end

  function M.setup(capabilities)
    local servers = {
    clangd = {
      root_dir = clangdRootDir,
      cmd = (function()
        local is_windows = vim.fn.has('win32') == 1
        local query_driver = is_windows
          and '--query-driver=/ucrt64/bin/g++'
          or '--query-driver=/usr/bin/c++,/usr/bin/clang++'
        local index_jobs = math.max(1, math.floor(vim.uv.available_parallelism() / 2))
        return {
          'clangd',
          '--log=error',
          '--background-index',
          -- 'low', not 'background': background maps to Windows
          -- THREAD_MODE_BACKGROUND_BEGIN + EcoQoS, which throttles the
          -- indexer's CPU and I/O scheduling so hard that a JUCE-sized
          -- index sweep never visibly completes. 'low' keeps the indexer
          -- yielding to interactive work and compiler jobs without the
          -- background-mode I/O starvation.
          '--background-index-priority=low',
          '-j=' .. index_jobs,
          '--header-insertion=never',
          '--clang-tidy',
          '--completion-style=detailed',
          '--header-insertion-decorators=false',
          query_driver,
        }
      end)(),
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
end

-- Manual escape hatch (<leader>bi): stops every clangd client and re-triggers
-- FileType on their buffers, which re-spawns clangd through the normal
-- LspAttach path. Two situations this recovers that the automatic design
-- (core/traffic.lua, core/clangd.lua) does not cover on its
-- own: a client wedged after a crash/invalid-AST error, and forcing a full
-- background-index sweep (clangd only re-checks shard staleness at its own
-- startup — see the --background-index-priority comment in M.setup — so
-- "reindex everything now" has no LSP-level command, only a restart).
function M.restart()
  local clients = vim.tbl_filter(function(c) return c.name == 'clangd' end, vim.lsp.get_clients())
  if #clients == 0 then
    vim.notify('clangd: no active client', vim.log.levels.WARN)
    return
  end

  local bufs = {}
  for _, client in ipairs(clients) do
    vim.list_extend(bufs, vim.tbl_keys(client.attached_buffers))
    client:stop()
  end

  local CLIENT_GONE_POLL_MS = 50
  local function restartWhenGone()
    for _, client in ipairs(clients) do
      if vim.lsp.get_client_by_id(client.id) ~= nil then
        vim.defer_fn(restartWhenGone, CLIENT_GONE_POLL_MS)
        return
      end
    end
    for _, buf in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' then
        local saved = vim.api.nvim_get_current_buf()
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
        vim.api.nvim_set_current_buf(saved)
      end
    end
    vim.notify('clangd: restarted', vim.log.levels.INFO)
  end
  restartWhenGone()
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
