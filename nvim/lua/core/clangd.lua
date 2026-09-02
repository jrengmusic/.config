-- core/clangd.lua
-- .clangd writer: reacts to ProjectChanged and applies clangd's
-- configuration from the project state -- one at the project root, one at
-- the user-module root -- plus the root copy of compile_commands.json.
-- Nothing here derives a project fact; every input is a field of the AST.
--
-- The root CDB copy keeps clangd's index shards (.cache/clangd, adjacent to
-- the CDB it serves) outside Builds/: a clean neither destroys the index
-- nor races clangd's file handles, and clangd hot-reloads the refreshed
-- copy on its own (compilationDatabase.automaticReload) -- no LSP restart.
local M = {}

local CLANGD_FILE = '.clangd'
local COMPILE_DATABASE = 'compile_commands.json'
local EVENT = 'ProjectChanged'

-- Remove: mirrors the locator's --target skip for the CDB's own commands --
-- a poisoned triple inside compile_commands.json would break those TUs
-- directly, .clangd Add hygiene notwithstanding.
local function getLines(databaseDir, flags, extraFlags)
  local lines = {
    'CompileFlags:',
    '  CompilationDatabase: ' .. databaseDir,
    '  Remove: [--target=*]',
    '  Add:',
  }
  for _, flag in ipairs(flags) do lines[#lines + 1] = '    - ' .. flag end
  for _, flag in ipairs(extraFlags) do lines[#lines + 1] = '    - ' .. flag end
  vim.list_extend(lines, {
    'Diagnostics:',
    '  MissingIncludes: None',
    '  UnusedIncludes: None',
  })
  return lines
end

local function writeIfDifferent(path, lines)
  local existing = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or nil
  if existing == nil or table.concat(existing, '\n') ~= table.concat(lines, '\n') then
    vim.fn.writefile(lines, path)
  end
end

-- Nanosecond mtime: two writes within one second still order correctly.
local function getModified(path)
  local stat = vim.uv.fs_stat(path)
  return stat and (stat.mtime.sec + stat.mtime.nsec / 1e9) or -1
end

-- Gated on the build CDB being newer than the root copy, so an incremental
-- build that never reconfigured copies nothing. The copy is large for a
-- JUCE project and runs on libuv's threadpool, off the main loop.
local function copyDatabase(database, rootDatabase)
  if getModified(database) > getModified(rootDatabase) then
    vim.uv.fs_copyfile(database, rootDatabase, function(err)
      if err then
        vim.schedule(function() vim.notify('clangd: compile database copy failed', vim.log.levels.ERROR) end)
      end
    end)
  end
end

-- Framework module headers are never compiled as their own translation
-- unit, so they have no CDB entry of their own; -include JuceHeader.h gives
-- clangd every JUCE declaration for standalone header analysis at the
-- user-module root. Both files point CompilationDatabase at the project
-- root copy. A project not built yet has no compile section and nothing
-- to apply.
function M.apply(ast)
  local compile = require('core.project').getCompile(ast)
  if compile then
    local root = ast.manifest.root
    local frameworkFlags = compile.juceHeader and { '-include', compile.juceHeader } or {}
    copyDatabase(compile.database, root .. '/' .. COMPILE_DATABASE)
    writeIfDifferent(root .. '/' .. CLANGD_FILE, getLines(root, compile.flags, {}))
    writeIfDifferent(ast.dependencies.user.root .. '/' .. CLANGD_FILE, getLines(root, compile.flags, frameworkFlags))
  end
end

function M.setup()
  vim.api.nvim_create_autocmd('User', {
    pattern = EVENT,
    callback = function(event)
      M.apply(require('core.project').getOrCreate(event.data.root))
    end,
    desc = 'Write .clangd and the root compile database from the project state',
  })
end

return M
