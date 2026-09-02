-- core/project.lua
-- The project state: one AST for the current project root, built once from
-- the project's sources by a toolchain locator, materialised to
-- <root>/.project for visibility, and replaced whole -- never patched --
-- whenever a source changes. Every editor operation (build, debug, clangd,
-- doxygen, navigator) reads this registry and reacts to the ProjectChanged
-- event; none derives a project fact on its own.
--
-- Shape follows jam::Document: the base drives parse/validate/write/events,
-- a locator (core/project/<toolchain>.lua) supplies TOOLCHAIN_MANIFEST and
-- build(). A root with no locator manifest is not a project -- getOrCreate
-- returns nil and every project operation reports so. nvim's working
-- directory is the project: loading a root evicts every other.
local M = {}

local STATE_FILE = '.project'
local LEGACY_SELECTION_FILE = '.nvim-dap-config'
local EVENT = 'ProjectChanged'
local WATCH_DEBOUNCE_MS = 300
local INDENT = '  '

local LOCATORS = { 'core.project.cast' }

local registry = {}
local watchers = {}

-- The registry key: every consumer addresses the state by this root.
function M.getRoot()
  return vim.fs.normalize(vim.fn.getcwd())
end

local function getLocator(root)
  for _, name in ipairs(LOCATORS) do
    local locator = require(name)
    if vim.fn.filereadable(root .. '/' .. locator.TOOLCHAIN_MANIFEST) == 1 then
      return locator
    end
  end
  return nil
end

local function getStatePath(root)
  return root .. '/' .. STATE_FILE
end

local function getLegacySelectionPath(root)
  return root .. '/' .. LEGACY_SELECTION_FILE
end

-- The pre-state selection file's content, as a selection; empty when absent.
local function getLegacySelection(root)
  local ok, legacy = pcall(dofile, getLegacySelectionPath(root))
  if ok and type(legacy) == 'table' then
    return { target = legacy.format, host = legacy.dawPath or '' }
  end
  return {}
end

-- selection is the one section not derived from a source: it is carried
-- from the previous materialisation into the next, or from the legacy
-- file when no materialisation exists yet.
local function getSelection(root)
  local ok, state = pcall(dofile, getStatePath(root))
  if ok and type(state) == 'table' and type(state.selection) == 'table' then
    return state.selection
  end
  return getLegacySelection(root)
end

-- A carried selection names only what the new document declares; a target
-- or configuration the manifest no longer declares (renamed, or a legacy
-- format name) is dropped, never kept as dead state. pid is carried
-- unconditionally -- it names a currently-running process, not a manifest
-- fact, so it survives a reparse regardless of what the manifest declares.
local function getDeclaredSelection(ast, selection)
  local targets = {}
  for _, target in ipairs(ast.targets) do targets[target.name] = true end
  return {
    configuration = ast.configurations[selection.configuration] and selection.configuration or nil,
    target = targets[selection.target] and selection.target or nil,
    host = selection.host or '',
    pid = selection.pid,
  }
end

local function isArray(value)
  return #value > 0 and next(value, #value) == nil
end

local function getSortedKeys(value)
  local keys = vim.tbl_keys(value)
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

local function getKeyText(key)
  if type(key) == 'string' and key:match('^[%a_][%w_]*$') then return key end
  return '[' .. (type(key) == 'string' and string.format('%q', key) or tostring(key)) .. ']'
end

local function serialize(value, depth)
  if type(value) ~= 'table' then
    return type(value) == 'string' and string.format('%q', value) or tostring(value)
  end
  local indent, inner = INDENT:rep(depth), INDENT:rep(depth + 1)
  local lines = { '{' }
  if isArray(value) then
    for _, item in ipairs(value) do
      lines[#lines + 1] = inner .. serialize(item, depth + 1) .. ','
    end
  else
    for _, key in ipairs(getSortedKeys(value)) do
      lines[#lines + 1] = inner .. getKeyText(key) .. ' = ' .. serialize(value[key], depth + 1) .. ','
    end
  end
  lines[#lines + 1] = indent .. '}'
  return table.concat(lines, '\n')
end

local function getText(ast)
  return 'return ' .. serialize(ast, 0) .. '\n'
end

local function writeIfDifferent(path, text)
  local lines = vim.split(text, '\n', { trimempty = true })
  local existing = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or nil
  if existing == nil or table.concat(existing, '\n') ~= table.concat(lines, '\n') then
    vim.fn.writefile(lines, path)
  end
end

-- Every way a built document can still be unusable, aggregated rather than
-- stopped at the first.
local function getFindings(ast)
  local findings = {}
  local function check(condition, message)
    if not condition then findings[#findings + 1] = message end
  end
  check(ast.manifest.name ~= nil and ast.manifest.name ~= '', 'manifest has no project name')
  check(next(ast.configurations) ~= nil, 'no configuration declared')
  check(#ast.targets > 0, 'no target declared')
  return findings
end

local function stopWatchers(root)
  for _, handle in ipairs(watchers[root] or {}) do
    handle:stop()
    handle:close()
  end
  watchers[root] = nil
end

-- One non-recursive watcher per source directory, filtered to the exact
-- source paths: robust to tools that replace a file by rename rather than
-- rewriting it in place, and blind to the other files those directories
-- hold (the root compile-database copy, .clangd, .project).
local function watch(root, ast)
  stopWatchers(root)

  local paths, directories = {}, {}
  for _, source in ipairs(ast.sources) do
    paths[source] = true
    directories[vim.fs.dirname(source)] = true
  end

  local timer = assert(vim.uv.new_timer())
  local function onChange(directory)
    return function(err, filename)
      if err == nil and paths[directory .. '/' .. filename] then
        timer:stop()
        timer:start(WATCH_DEBOUNCE_MS, 0, vim.schedule_wrap(function() M.parse(root) end))
      end
    end
  end

  watchers[root] = { timer }
  for directory in pairs(directories) do
    local watcher = assert(vim.uv.new_fs_event())
    watcher:start(directory, {}, onChange(directory))
    watchers[root][#watchers[root] + 1] = watcher
  end
end

local function build(root, locator, selection)
  local ast, failure = locator.build(root, selection or getSelection(root))
  if ast == nil then return nil, { failure } end

  ast.selection = getDeclaredSelection(ast, ast.selection)
  local findings = getFindings(ast)
  if #findings == 0 then return ast end
  return nil, findings
end

-- The working directory is the project: any other loaded root is evicted
-- with its watchers, so one document answers every lookup.
local function evictOthers(root)
  for other in pairs(registry) do
    if other ~= root then
      stopWatchers(other)
      registry[other] = nil
    end
  end
end

-- Rebuilds the document from its sources and replaces the registry entry.
-- selection, when given, replaces the carried one (a state update). The
-- legacy selection file is removed once a materialisation exists.
function M.parse(root, selection)
  evictOthers(root)
  local locator = getLocator(root)
  local ast, findings = nil, nil
  if locator then ast, findings = build(root, locator, selection) end
  if findings then vim.notify('project: ' .. table.concat(findings, '; '), vim.log.levels.ERROR) end

  registry[root] = ast
  if ast then
    writeIfDifferent(getStatePath(root), getText(ast))
    vim.fn.delete(getLegacySelectionPath(root))
    watch(root, ast)
    vim.api.nvim_exec_autocmds('User', { pattern = EVENT, data = { root = root } })
  end
  return ast
end

function M.getOrCreate(root)
  return registry[root] or M.parse(root)
end

function M.setSelection(root, selection)
  assert(registry[root], 'project: no state for ' .. root)
  return M.parse(root, selection)
end

-- The launched process's PID, written directly into the current state and
-- persisted -- no reparse, no ProjectChanged: a PID is bookkeeping for
-- terminate to kill immediately, not a project fact any listener reacts to.
-- pid = nil clears it once the process is gone.
function M.setLaunchedPid(root, pid)
  local ast = assert(registry[root], 'project: no state for ' .. root)
  ast.selection.pid = pid
  writeIfDifferent(getStatePath(root), getText(ast))
end

-- The compile section clangd and the navigator follow: the selected
-- configuration once it has been built, otherwise the first built
-- configuration in key order.
function M.getCompile(ast)
  local selected = ast.compile[ast.selection.configuration]
  if selected then return selected end
  local keys = getSortedKeys(ast.compile)
  return ast.compile[keys[1]]
end

local function isUnder(path, root)
  return path:lower():sub(1, #root + 1) == root:lower() .. '/'
end

-- The loaded project a file belongs to: its own tree, or its user-module
-- tree (framework sources are compiled only by the project that builds
-- them, so they answer to that project's compile database).
function M.getProjectFor(path)
  local normalized = vim.fs.normalize(path)
  for _, ast in pairs(registry) do
    if isUnder(normalized, ast.manifest.root) or isUnder(normalized, ast.dependencies.user.root) then
      return ast
    end
  end
  return nil
end

function M.stop()
  for root in pairs(watchers) do stopWatchers(root) end
end

return M
