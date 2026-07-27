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

  function M.setup(capabilities)
    local servers = {
    clangd = {
      root_dir = clangdRootDir,
      cmd = (function()
        local is_windows = vim.fn.has('win32') == 1
        local clangd_bin = is_windows
          and 'clangd'  -- system clangd via winget LLVM (Mason's clangd is .cmd, won't work)
          or (vim.fn.stdpath('data') .. '/mason/bin/clangd')
        local query_driver = is_windows
          and '--query-driver=/mingw64/bin/g++'
          or '--query-driver=/usr/bin/c++,/usr/bin/clang++'
        local index_jobs = math.max(1, math.floor(vim.uv.available_parallelism() / 2))
        return {
          clangd_bin,
          '--log=error',
          '--background-index',
          '--background-index-priority=background',
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
  local tools = { 'stylua', 'prettier' }
  vim.list_extend(tools, server_names)
  require('mason-tool-installer').setup({ ensure_installed = tools })

  require('mason-lspconfig').setup({
    ensure_installed = server_names,
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
