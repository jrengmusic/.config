-- Autocommands
local M = {}

local CLANGD_WATCH_DEBOUNCE_MS = 300
local DOXYGEN_WATCH_DEBOUNCE_MS = 300000
local LSP_STOP_TIMEOUT_MS = 5000

-- Nvim mirrors every LSP client's stderr into stdpath('log')/lsp.log at
-- ERROR severity with no rotation (vim/lsp/log.lua). clangd's own stderr
-- chatter during indexing floods it unbounded across months of sessions, so
-- each session starts from an empty file instead of accumulating history.
local function truncateLspLog()
  local log_path = vim.lsp.log.get_filename()
  if vim.fn.filereadable(log_path) == 1 then
    vim.fn.writefile({}, log_path)
  end
end

-- Calls onIdle once client has no in-flight $/progress work (e.g. clangd's
-- background-indexing). client.progress.pending is a token->title table,
-- populated on a "begin" progress event and cleared on "end"
-- (vim/lsp/handlers.lua) — emptiness is the standard LSP signal for "no
-- work in progress", not a clangd-specific parse. Killing a client mid-index
-- doesn't corrupt anything (the next spawn re-indexes from scratch either
-- way), but doing it while idle avoids compounding wasted index work across
-- several .clangd rewrites landing in quick succession from one reconfigure.
local function onClientIdle(client, onIdle)
  if vim.tbl_isempty(client.progress.pending) then
    onIdle()
    return
  end
  local clientId = client.id
  vim.api.nvim_create_autocmd('LspProgress', {
    pattern = 'end',
    callback = function(event)
      if event.data.client_id ~= clientId then return end
      local c = vim.lsp.get_client_by_id(clientId)
      if c == nil or vim.tbl_isempty(c.progress.pending) then
        onIdle()
        return true
      end
    end,
  })
end

-- Client ids currently mid-restart (onClientIdle armed or client:stop()
-- already called for them). watchClangdConfig's debounce timer can invoke
-- refreshLsp again while a previous call is still waiting on the same
-- still-alive client — without this guard that registers a second
-- LspProgress/LspDetach waiter pair for the same clientId, so the eventual
-- exit fires both, double-triggering FileType and client:stop(). Same
-- single-flight precedent as doxygen.lua's active_job_id.
local restartingClients = {}

-- Calls onGone once clientId is fully gone from vim.lsp.client._all (the
-- same table vim.lsp.get_client_by_id / get_clients read). LspDetach fires
-- from inside Client:_on_detach (vim/lsp/client.lua) *before* that removal
-- — attached_buffers[bufnr] isn't cleared until after the autocmd dispatch
-- returns, and the client's entry in _all is cleared even later, in a
-- nested vim.schedule inside _on_exit ("so it exists in the execution of
-- autocommands", per that function's own comment). Firing FileType inside
-- the LspDetach callback itself therefore retriggers LSP autostart while
-- the dying client is still visible to vim.lsp.get_clients() (which does
-- not filter by is_stopped()), a state a fresh nvim start never has.
-- Polling get_client_by_id ties the retrigger to that removal directly
-- instead of guessing how many scheduler ticks it takes.
local function waitForClientGone(clientId, onGone)
  if vim.lsp.get_client_by_id(clientId) == nil then
    onGone()
    return
  end
  vim.schedule(function() waitForClientGone(clientId, onGone) end)
end

-- Restarts every attached LSP client — called only by watchClangdConfig,
-- once .clangd itself has actually changed on disk.
--
-- client:stop() is asynchronous — it sends a shutdown request and the
-- client only actually dies later, once the server process exits. Waiting
-- on LspDetach (fired only after that real exit) instead of a fixed delay
-- means the new client never races the old one's teardown. A bounded
-- force-stop timeout is required: clients default to exit_timeout=false
-- (no escalation), so a server that never answers "shutdown" — e.g.
-- clangd deferring it while background-indexing — would otherwise stall
-- LspDetach, and the restart, forever. onClientIdle additionally holds off
-- the stop itself until the client's current background work has settled.
local function refreshLsp()
  for _, client in ipairs(vim.lsp.get_clients()) do
    local clientId = client.id
    if not restartingClients[clientId] then
      restartingClients[clientId] = true
      local bufs = vim.tbl_keys(client.attached_buffers)
      onClientIdle(client, function()
        for _, buf in ipairs(bufs) do
          if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' then
            vim.api.nvim_create_autocmd('LspDetach', {
              buffer = buf,
              callback = function(event)
                if event.data.client_id == clientId then
                  waitForClientGone(clientId, function()
                    local saved = vim.api.nvim_get_current_buf()
                    vim.api.nvim_set_current_buf(buf)
                    vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
                    vim.api.nvim_set_current_buf(saved)
                  end)
                  return true
                end
              end,
            })
          end
        end
        client:stop(LSP_STOP_TIMEOUT_MS)
      end)
    end
  end
end

-- Watches the build directory (Builds/Ninja/Debug/) for *any* file
-- activity — not just compile_commands.json. A clean rebuild regenerates
-- JuceHeader.h, generated headers, binary data libs, and .clangd all at
-- different times during the build. Clangd attaching mid-build caches a
-- stale preamble against transient/absent headers, and nothing tells it to
-- re-check later. The debounce timer resets on every single fs event in
-- the directory, so the callback only fires once the *entire* directory
-- has been quiet for CLANGD_WATCH_DEBOUNCE_MS — meaning the build has
-- settled. At that point it syncs .clangd (no-op if compile_commands.json
-- didn't change), then restarts LSP so clangd re-parses with all
-- generated headers in their final state.
local function watchBuildDir()
  local cmakePicker = require('core.cmake-picker')
  local compile_db = cmakePicker.find_compile_db()
  if compile_db == nil then return end

  local db_dir = vim.fn.fnamemodify(compile_db, ':h')
  local watcher = assert(vim.uv.new_fs_event())
  local debounce_timer = assert(vim.uv.new_timer())

  watcher:start(db_dir, {}, function(err)
    if err ~= nil then return end
    debounce_timer:stop()
    debounce_timer:start(CLANGD_WATCH_DEBOUNCE_MS, 0, vim.schedule_wrap(function()
      cmakePicker.syncClangd()
      refreshLsp()
    end))
  end)

  vim.api.nvim_create_autocmd('VimLeavePre', {
    once = true,
    callback = function()
      watcher:stop()
      debounce_timer:stop()
    end,
    desc = 'Stop build directory watcher before quitting',
  })
end

-- Watches the same source trees build_incremental checks for staleness
-- (JUCE modules, framework lib, project Source — see doxygen.get_watch_dirs)
-- and lazily rebuilds only what's stale. Not tied to binary build
-- completion: sources change on every save, far more often than a build
-- happens, so this is debounced long (DOXYGEN_WATCH_DEBOUNCE_MS) rather
-- than short like watchCompileDb — the debounce resets on every edit, so
-- it only fires once editing has been idle for the full window, and never
-- interrupts an active editing burst. Recursive per-tree watch, since each
-- tree is a real directory hierarchy (unlike compile_commands.json's single
-- file). warnings/errors still surface via run_in_terminal's terminal split
-- (core/doxygen.lua) — only the trigger point moved, not the output.
local function watchDoxygenSources()
  local doxygen = require('core.doxygen')
  local root = doxygen.get_project_root()
  local watch_dirs = doxygen.get_watch_dirs(root)
  if watch_dirs == nil then return end

  local debounce_timer = assert(vim.uv.new_timer())
  local watchers = {}

  local function on_source_change(err)
    if err ~= nil then return end
    debounce_timer:stop()
    debounce_timer:start(DOXYGEN_WATCH_DEBOUNCE_MS, 0, vim.schedule_wrap(function()
      doxygen.build_incremental(root)
    end))
  end

  for _, dir in ipairs(watch_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local watcher = assert(vim.uv.new_fs_event())
      watcher:start(dir, { recursive = true }, on_source_change)
      table.insert(watchers, watcher)
    end
  end

  vim.api.nvim_create_autocmd('VimLeavePre', {
    once = true,
    callback = function()
      for _, watcher in ipairs(watchers) do watcher:stop() end
      debounce_timer:stop()
    end,
    desc = 'Stop doxygen source-tree watchers before quitting',
  })
end

function M.setup()
  truncateLspLog()

  -- Sync .clangd from compile_commands.json on startup, then arm the
  -- build directory watcher (see watchBuildDir doc comment) plus the
  -- doxygen source-tree watcher.
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      vim.schedule(function()
        require('core.cmake-picker').syncClangd()
        watchBuildDir()
        watchDoxygenSources()
      end)
    end,
    desc = 'Sync .clangd on startup; watch build dir and doxygen sources for changes',
  })

  -- Stop any build/clean/doxygen job still running on quit. Nvim itself only
  -- guarantees this for LSP clients (vim.lsp's own VimLeavePre asks clangd to
  -- shut down); jobstart/termopen jobs are never auto-killed by Nvim on any
  -- platform — on Unix they're spawned detached (setsid) so :qa leaves them
  -- running regardless, on Windows the OS Job Object only catches direct
  -- children on crash, not this cooperative-quit path. Identical on both OS:
  -- same two calls, no platform branch.
  vim.api.nvim_create_autocmd('VimLeavePre', {
    once = true,
    callback = function()
      require('core.build').stopActiveBuildJob()
      require('core.doxygen').stop_active_job()
    end,
    desc = 'Stop in-flight build/clean/doxygen jobs before quitting',
  })

  -- Live keymap lexicon regen: saving KEYMAPS.md regenerates keymaps.lua
  -- immediately. Launch-time verify() in init.lua remains the backstop for
  -- edits arriving via git pull from other machines.
  vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = vim.fn.stdpath('config'):gsub('\\', '/') .. '/doc/KEYMAPS.md',
    callback = function()
      require('core.keymaps-generator').verify()
    end,
    desc = 'Regenerate keymaps.lua from the KEYMAPS.md lexicon',
  })

  -- Filetype overrides
  vim.filetype.add({
    extension = {
      mm = 'objcpp',
    },
  })

  -- Use // for C++ comments instead of /* */
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'cpp', 'c', 'objc', 'objcpp' },
    callback = function()
      vim.opt_local.commentstring = '// %s'
    end,
    desc = 'Set C++ style line comments',
  })

  -- Highlight on yank
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking text',
    group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
    callback = function()
      vim.highlight.on_yank()
    end,
  })

  -- Format on mode change (command to normal)
  vim.api.nvim_create_autocmd('ModeChanged', {
    pattern = { 'c:n' },
    callback = function()
      if not vim.bo.modifiable or vim.bo.buftype ~= '' then
        return
      end
      local filetype = vim.bo.filetype
      if filetype == 'cpp' or filetype == 'c' or filetype == 'objc' or filetype == 'objcpp' then
        vim.schedule(function()
          require('core.formatting').formatBuffer()
        end)
      else
        vim.schedule(function()
          require('core.formatting').formatWithConform()
        end)
      end
    end,
    desc = 'Format on mode change',
  })

  -- Format C/C++ on save
  vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = { '*.cpp', '*.c', '*.h', '*.hpp', '*.objc', '*.objcpp', '*.mm' },
    callback = function()
      require('core.formatting').formatBuffer()
    end,
    desc = 'Format C/C++ on save',
  })

  -- Terminal error highlighting
  vim.api.nvim_create_autocmd('TermOpen', {
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      
      -- Highlight error indicators (^^^^^^^ and ~~~~~~~ lines)
      vim.api.nvim_buf_call(buf, function()
        vim.fn.matchadd('TerminalCaret', '\\^\\+')
        vim.fn.matchadd('ErrorMsg', '\\~\\+')
        vim.fn.matchadd('DiagnosticError', '\\^\\+\\s*$')
        vim.fn.matchadd('DiagnosticError', '\\~\\+\\s*$')
      end)
      
      -- Also highlight common compiler error patterns
      vim.api.nvim_buf_call(buf, function()
        vim.fn.matchadd('DiagnosticError', '\\cerror:')
        vim.fn.matchadd('DiagnosticWarn', '\\cwarning:')
        vim.fn.matchadd('DiagnosticInfo', '\\cnote:')
        
        -- Highlight file paths, filenames, and line/column numbers
        -- Match "from /path/to/filename.ext:" patterns
        
        -- Just the filename (last part of path) with cyan color
        vim.api.nvim_set_hl(0, 'TerminalFilename', { fg = '#00FFFF', bold = false })
        vim.fn.matchadd('TerminalFilename', '\\w\\+\\.\\w\\+\\ze:\\d')
        
        -- Line number in green
        vim.fn.matchadd('TerminalLineNumber', ':\\zs\\d\\+\\ze:')
        
        -- Column number in yellow
        vim.fn.matchadd('DiagnosticWarn', ':\\d\\+:\\zs\\d\\+')

        -- C++ syntax highlighting for code snippets in errors
        -- Preprocessor directives
        vim.api.nvim_set_hl(0, 'TerminalPreproc', { fg = '#9aff00', bold = true })
        vim.fn.matchadd('TerminalPreproc', '^\\s*#include\\>')
        vim.fn.matchadd('TerminalPreproc', '^\\s*#define\\>')
        vim.fn.matchadd('TerminalPreproc', '^\\s*#if\\>')
        vim.fn.matchadd('TerminalPreproc', '^\\s*#else\\>')
        vim.fn.matchadd('TerminalPreproc', '^\\s*#endif\\>')
        vim.fn.matchadd('TerminalPreproc', '^\\s*#ifdef\\>')
        vim.fn.matchadd('TerminalPreproc', '^\\s*#ifndef\\>')

        -- String literals
        vim.api.nvim_set_hl(0, 'TerminalString', { fg = '#ffc0c0' })
        vim.fn.matchadd('TerminalString', '"[^"]*"')
        vim.fn.matchadd('TerminalString', "'[^']*'")

        -- Keywords
        vim.api.nvim_set_hl(0, 'TerminalKeyword', { fg = '#1919ff', bold = true })
        local keywords = {'if', 'else', 'for', 'while', 'return', 'void', 'int', 'float', 'double', 'bool', 'char', 'unsigned', 'const', 'static', 'class', 'struct', 'public', 'private', 'protected', 'virtual', 'inline', 'constexpr', 'auto', 'decltype', 'template', 'typename'}
        for _, kw in ipairs(keywords) do
          vim.fn.matchadd('TerminalKeyword', '\\<' .. kw .. '\\>')
        end

        -- Function names (followed by opening paren)
        vim.api.nvim_set_hl(0, 'TerminalFunction', { fg = '#80ffff' })
        vim.fn.matchadd('TerminalFunction', '\\<\\w\\+\\>(')
      end)
    end,
    desc = 'Highlight error indicators in terminal',
  })
end

return M
