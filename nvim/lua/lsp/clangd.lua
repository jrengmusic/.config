-- Clangd LSP configuration
local M = {}

-- Cross-platform path comparison: Windows paths mix native backslashes with
-- the forward-slash paths .clangd's CompilationDatabase entries use — same
-- normalize-then-compare convention as core/actions.lua's jump-sync cwd check.
local function normalizePath(path)
  return path:gsub('\\', '/'):lower()
end

-- Extracts CompilationDatabase: <dir> out of a .clangd file's CompileFlags
-- block. A framework repo (e.g. KANJUT at kuassa/___lib___) has its own
-- .clangd for version-control independence, but declares a CompilationDatabase
-- belonging to whichever plugin project actually builds it — that's what
-- clangdRootDir below reads to detect the split.
local function readCompilationDatabaseDir(clangd_file)
  for _, line in ipairs(vim.fn.readfile(clangd_file)) do
    local db = line:match('^%s*CompilationDatabase:%s*(.-)%s*$')
    if db then return db end
  end
  return nil
end

-- The default root_markers = {'.clangd', '.git'} treats every git repo as
-- its own LSP root — correct for an independent project, wrong for a
-- framework repo whose .clangd points its CompilationDatabase at a
-- *different* repo's build directory (the only place it's ever actually
-- compiled). Left alone, that spawns a second clangd instance
-- background-indexing the same compile_commands.json in parallel with the
-- first, doubling indexing time and CPU contention. This resolves root_dir
-- to the CompilationDatabase's own project instead whenever the two
-- diverge, so one clangd instance answers for both trees.
local function clangdRootDir(bufnr, on_dir)
  local clangd_root = vim.fs.root(bufnr, '.clangd')
  local own_root = clangd_root or vim.fs.root(bufnr, '.git')

  if clangd_root then
    local db_dir = readCompilationDatabaseDir(clangd_root .. '/.clangd')
    if db_dir and normalizePath(db_dir):sub(1, #normalizePath(own_root)) ~= normalizePath(own_root) then
      on_dir(vim.fs.root(db_dir, '.git') or db_dir)
      return
    end
  end

  on_dir(own_root)
end

-- Mason's clangd package ships the official LLVM release binary on both
-- platforms. On macOS mason/bin/clangd is a plain symlink to it; on Windows
-- mason/bin/clangd.cmd is a batch shim libuv can't spawn directly, so the
-- real exe inside the versioned package directory is resolved instead.
-- Before mason-tool-installer's first install completes the glob is empty —
-- the shim path is returned as a placeholder and the next nvim start
-- resolves the real exe (same first-boot window the macOS path has).
local function clangdBinary(is_windows)
  if is_windows then
    local exes = vim.fn.glob(vim.fn.stdpath('data') .. '/mason/packages/clangd/clangd_*/bin/clangd.exe', false, true)
    if #exes > 0 then return exes[#exes] end
    return vim.fn.stdpath('data') .. '/mason/bin/clangd'
  end
  return vim.fn.stdpath('data') .. '/mason/bin/clangd'
end

  function M.setup(capabilities)
    local servers = {
    clangd = {
      root_dir = clangdRootDir,
      cmd = (function()
        local is_windows = vim.fn.has('win32') == 1
        local query_driver = is_windows
          and '--query-driver=/mingw64/bin/g++'
          or '--query-driver=/usr/bin/c++,/usr/bin/clang++'
        local index_jobs = math.max(1, math.floor(vim.uv.available_parallelism() / 2))
        return {
          clangdBinary(is_windows),
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
      gopls = {},
      zls = {},
      ts_ls = {},
    pyright = {},
      -- cmake excluded: Mason requires python <3.14, MSYS2 ships 3.14+.
      -- cmake-language-server is installed via pipx (step 4d in setup-windows.sh).
      -- mason-lspconfig auto-enables it from PATH without Mason managing it.
    }

  -- node-dependent servers: only include when node is in PATH
  -- (Mason needs npm to install pyright and ts_ls)
  local has_node = vim.fn.executable('node') == 1
  if not has_node then
    servers.ts_ls = nil
    servers.pyright = nil
  end

  local server_names = vim.tbl_keys(servers)

  -- Apply per-server config (cmd, capabilities, settings) via vim.lsp.config.
  -- mason-lspconfig v2 dropped handlers; automatic_enable calls vim.lsp.enable()
  -- which reads from vim.lsp.config. Config must be set before enable fires.
  for name, cfg in pairs(servers) do
    vim.lsp.config(name, vim.tbl_deep_extend('force', cfg, { capabilities = capabilities }))
  end

  -- mason-tool-installer: deduplicated list of LSPs + standalone tools
  local tools = { 'stylua' }
  vim.list_extend(tools, server_names)
  require('mason-tool-installer').setup({ ensure_installed = tools })

  require('mason-lspconfig').setup({
    ensure_installed = server_names,
  })
end

-- Manual escape hatch (<leader>bi): stops every clangd client and re-triggers
-- FileType on their buffers, which re-spawns clangd through the normal
-- LspAttach path. Two situations this recovers that the automatic design
-- (core/traffic.lua, core/cmake-picker.syncClangd) does not cover on its
-- own: a client wedged after a crash/invalid-AST error, and forcing a full
-- background-index sweep (clangd only re-checks shard staleness at its own
-- startup — see lsp/clangd.lua's --background-index-priority comment — so
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
