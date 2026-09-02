-- dap/launch.lua
-- DAP launch from the project state (core/project.lua): the selection
-- picker (target, host), the DAP configuration for a target, and the host
-- process lookup. Every value is a field of the AST -- targets carry their
-- product path per configuration, launch carries the request shape --
-- nothing here globs artefacts or reads a manifest.
local M = {}

local is_windows = vim.fn.has('win32') == 1

local EVENT = 'ProjectChanged'
local PICK_RETRY_MS = 100
local HOST_PATTERNS_WINDOWS = {
  'C:/Program Files/*/*.exe',
  'C:/Program Files/*/*/*.exe',
  'C:/Program Files (x86)/*/*.exe',
  'C:/Program Files (x86)/*/*/*.exe',
}
local HOST_SCAN_MAC = 'find "/Applications" -maxdepth 2 -name "*.app" -type d 2>/dev/null'
-- Picker order: executable targets (Standalone) lead, so the first entry
-- -- the picker's default -- runs the standalone unless a plugin host is
-- picked.
local PICK_ORDER = { 'executable', 'plugin' }

local function getTarget(project, name)
  for _, target in ipairs(project.targets) do
    if target.name == name then return target end
  end
  return nil
end

-- Host process id by executable name: tasklist on Windows, pgrep -x on
-- macOS. Errors (not running) surface to dap.run as a launch failure.
function M.getHostPid(host)
  local name = vim.fs.basename(host)
  local handle
  if is_windows then
    handle = io.popen('tasklist /FI "IMAGENAME eq ' .. vim.fn.fnamemodify(name, ':r') .. '.exe" /FO CSV /NH 2>nul')
  else
    handle = io.popen("pgrep -x '" .. name .. "' 2>/dev/null | head -1")
  end
  assert(handle, 'launch: failed to query host process ' .. name)
  local output = handle:read('*l')
  handle:close()

  local pid = output and (is_windows and output:match('"[^"]+","(%d+)"') or output)
  if pid and tonumber(pid) then return tonumber(pid) end
  error('Host not running: ' .. name .. '. Launch it first.')
end

-- Every launchable application on this machine, as picker items.
local function getHostApplications()
  local applications = {}
  if is_windows then
    for _, pattern in ipairs(HOST_PATTERNS_WINDOWS) do
      for _, path in ipairs(vim.fn.glob(pattern, false, true)) do
        path = path:gsub('\\', '/')
        applications[#applications + 1] = { text = path, file = path }
      end
    end
  else
    local handle = io.popen(HOST_SCAN_MAC)
    if handle then
      for line in handle:lines() do
        applications[#applications + 1] = { text = line, file = line }
      end
      handle:close()
    end
  end
  return applications
end

-- macOS: a .app bundle unwraps to its executable.
local function getHostExecutable(path)
  if not is_windows and path:match('%.app/?$') then
    return path:gsub('/$', '') .. '/Contents/MacOS/' .. vim.fn.fnamemodify(path, ':t:r')
  end
  return path
end

local function pickHost(callback)
  local applications = getHostApplications()
  if #applications == 0 then
    vim.notify('No applications found', vim.log.levels.ERROR)
  else
    require('snacks').picker({
      items = applications,
      prompt = 'Select host application: ',
      format = 'file',
      confirm = function(picker, item)
        picker:close()
        local host = item and item.file and getHostExecutable(item.file)
        if host == nil then
          vim.notify('Selection cancelled: no host selected')
        elseif vim.fn.filereadable(host) == 1 then
          callback(host)
        else
          vim.notify('Host executable not found: ' .. host .. '. Try again.')
          vim.defer_fn(function() pickHost(callback) end, PICK_RETRY_MS)
        end
      end,
    })
  end
end

local function getPickOrder(targets)
  local names = {}
  for _, kind in ipairs(PICK_ORDER) do
    for _, target in ipairs(targets) do
      if target.kind == kind then names[#names + 1] = target.name end
    end
  end
  return names
end

local function pickTarget(project, callback)
  local names = getPickOrder(project.targets)
  if #names == 1 then
    callback(names[1])
  else
    vim.ui.select(names, { prompt = 'Select target:' }, function(name)
      if name then callback(name) end
    end)
  end
end

-- Picker: target, then host for a plugin target. One state update
-- persists target, host, and the configuration the caller is about to
-- build (selection is carried into every later parse).
function M.pick(project, configuration, callback)
  local root = project.manifest.root
  pickTarget(project, function(name)
    local function save(host)
      local selection = { target = name, host = host, configuration = configuration or project.selection.configuration }
      local updated = require('core.project').setSelection(root, selection)
      if callback then callback(updated.selection) end
    end
    if getTarget(project, name).kind == 'plugin' then
      pickHost(save)
    else
      save('')
    end
  end)
end

local function isComplete(project)
  local target = getTarget(project, project.selection.target)
  if target == nil then return false end
  if target.kind == 'executable' then return true end
  return project.selection.host ~= '' and vim.fn.filereadable(project.selection.host) == 1
end

-- The selection to build and launch under `configuration`: the stored one
-- when complete (re-persisted only if the configuration changes),
-- otherwise created by the picker.
function M.getOrCreateSelection(project, configuration, callback)
  if not isComplete(project) then
    M.pick(project, configuration, callback)
  elseif project.selection.configuration == configuration then
    callback(project.selection)
  else
    local selection = vim.tbl_extend('force', project.selection, { configuration = configuration })
    callback(require('core.project').setSelection(project.manifest.root, selection).selection)
  end
end

-- Resolved at run time against the registry, so the product follows the
-- configuration that was last built.
local function getProduct(root, name)
  local project = require('core.project').getOrCreate(root)
  local configuration = project.selection.configuration
  assert(configuration, 'launch: build first')
  return getTarget(project, name).product[configuration]
end

local function getHost(root)
  return require('core.project').getOrCreate(root).selection.host
end

-- What each request shape needs beyond the common fields. The request
-- itself is already platform-resolved in the AST (launch[target]): a
-- plugin host is launched under the debugger on Windows, attached to on
-- macOS.
local PROGRAM = {
  executable = function(root, name)
    return { program = function() return getProduct(root, name) end, args = {} }
  end,
  plugin = function(root, name, request)
    if request == 'launch' then
      return { program = function() return getHost(root) end, console = 'integratedTerminal' }
    end
    return {
      program = function() return getProduct(root, name) end,
      pid = function() return M.getHostPid(getHost(root)) end,
    }
  end,
}

function M.getConfiguration(project, name)
  local target = getTarget(project, name)
  local launch = project.launch[name]
  local root = project.manifest.root
  return vim.tbl_extend('error',
    { name = name, type = launch.adapter, request = launch.request, cwd = root, stopOnEntry = false },
    PROGRAM[target.kind](root, name, launch.request))
end

-- Publishes one DAP configuration per target, so dap.continue's own menu
-- offers exactly the project's targets.
function M.apply(project)
  local dap = require('dap')
  local configurations = {}
  for _, target in ipairs(project.targets) do
    configurations[#configurations + 1] = M.getConfiguration(project, target.name)
  end
  dap.configurations.cpp = configurations
  dap.configurations.c = configurations
  dap.configurations.objcpp = configurations
end

function M.setup()
  vim.api.nvim_create_autocmd('User', {
    pattern = EVENT,
    callback = function(event)
      M.apply(require('core.project').getOrCreate(event.data.root))
    end,
    desc = 'Publish DAP configurations from the project state',
  })
  local project = require('core.project').getOrCreate(require('core.project').getRoot())
  if project then M.apply(project) end
end

return M
