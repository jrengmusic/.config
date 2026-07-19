-- Autocommands
local M = {}

local CLANGD_WATCH_DEBOUNCE_MS = 300
local LSP_REFRESH_DELAY_MS = 500
local DOXYGEN_WATCH_DEBOUNCE_MS = 300000

-- Re-syncs .clangd and restarts LSP clients only when compile flags
-- actually changed — a restart forces clangd to cold-reindex the whole
-- project, so skip it when the compile flags didn't move.
local function syncClangdAndRefreshLsp()
  local _, clangdChanged = require('core.cmake-picker').syncClangd()
  if not clangdChanged then return end

  for _, client in ipairs(vim.lsp.get_clients()) do
    local bufs = vim.tbl_keys(client.attached_buffers)
    client:stop()
    for _, buf in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' then
        vim.defer_fn(function()
          local saved = vim.api.nvim_get_current_buf()
          vim.api.nvim_set_current_buf(buf)
          vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
          vim.api.nvim_set_current_buf(saved)
        end, LSP_REFRESH_DELAY_MS)
      end
    end
  end
end

-- Watches compile_commands.json for changes (CMake reconfigure — added/
-- removed source file, changed compile flags) and lazily re-syncs .clangd.
-- Not tied to build completion: ordinary recompiles never touch this file,
-- so watching it directly fires far less often than "every build". The
-- directory (not the file) is watched because generators commonly replace
-- the file via rename rather than in-place write, which a file-level watch
-- would miss. Debounced since a reconfigure touches several files in the
-- same directory in quick succession.
local function watchCompileDb()
  local cmakePicker = require('core.cmake-picker')
  local compile_db = cmakePicker.find_compile_db()
  if compile_db == nil then return end

  local db_dir = vim.fn.fnamemodify(compile_db, ':h')
  local db_name = vim.fn.fnamemodify(compile_db, ':t')
  local watcher = assert(vim.uv.new_fs_event())
  local debounce_timer = assert(vim.uv.new_timer())

  watcher:start(db_dir, {}, function(err, filename)
    if err ~= nil or filename ~= db_name then return end
    debounce_timer:stop()
    debounce_timer:start(CLANGD_WATCH_DEBOUNCE_MS, 0, vim.schedule_wrap(syncClangdAndRefreshLsp))
  end)

  vim.api.nvim_create_autocmd('VimLeavePre', {
    once = true,
    callback = function()
      watcher:stop()
      debounce_timer:stop()
    end,
    desc = 'Stop compile_commands.json watcher before quitting',
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
  -- Sync .clangd from compile_commands.json on startup, then watch it for
  -- lazy re-sync (see watchCompileDb doc comment). Also arms the doxygen
  -- source-tree watcher (see watchDoxygenSources doc comment).
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      vim.schedule(function()
        require('core.cmake-picker').syncClangd()
        watchCompileDb()
        watchDoxygenSources()
      end)
    end,
    desc = 'Sync .clangd on startup; watch compile_commands.json and doxygen sources for changes',
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
