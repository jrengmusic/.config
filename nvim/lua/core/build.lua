-- core/build.lua
-- Build + DAP session orchestration for the project state
-- (core/project.lua). Bodies only — bindings live in core/keymaps.lua
-- (generated from nvim/doc/KEYMAPS.md; rows reference these as @build.*).
--
-- All job spawning/stopping goes through core/traffic.lua — the SSOT state
-- machine that enforces one active build/clean job per session. This module
-- owns only the UI around those jobs (plain log windows fed by traffic's
-- batched onLines — see openLogWindow — notifications, DAP launch
-- sequencing). The toolchain itself is core/cast-build.lua; what to launch
-- afterwards is the state's selection (dap/launch.lua).
--
-- clangd is never touched here: its CDB and index shards live at the
-- project root, outside Builds/ (see core/clangd.lua), so builds and
-- cleans neither contend with its file handles nor require an LSP restart
-- — clangd hot-reloads a reconfigured CDB on its own.
--
-- Runtime buffer-local keymaps spawned by behavior (bindAbort's <Esc>, the
-- build-failure q-to-close) live here by design — the lexicon covers
-- static bindings only.
local M = {}

local is_windows = vim.fn.has('win32') == 1

local DAP_TERMINATE_GRACE_MS = 200
-- The freshly launched executable is not always visible to the OS process
-- query on the first attempt — poll until it appears.
local PID_CAPTURE_DELAY_MS = 500
local PID_CAPTURE_RETRY_MS = 500
local PID_CAPTURE_MAX_ATTEMPTS = 10
-- Host processes need a moment to come up before an attach; a plain launch
-- only needs the build artefacts to settle.
local LAUNCH_DELAY_MS = { launch = 1000, attach = 2000 }
local LOG_WINDOW_HEIGHT = 15
local NOTIFY_TIMEOUT_MS = 1500

-- Both compiler dialects the toolchain produces: MSVC's
-- 'file(line): error C1234: msg' and clang/gcc's 'file:line:col: error: msg'.
-- %t consumes the leading letter as the entry type (e/w).
local BUILD_ERRORFORMAT = table.concat({
  [[%f(%l): %trror %m]],
  [[%f(%l): %tarning %m]],
  [[%f:%l:%c: %trror: %m]],
  [[%f:%l:%c: %tarning: %m]],
}, ',')
local BUILD_GUARD_LISTENER_KEY = 'build_guard'
local STANDALONE_PID_LISTENER_KEY = 'standalone_pid_capture'

local standalonePid = nil

local function getProject()
  local project = require('core.project')
  return project.getOrCreate(project.getRoot())
end

-- The project-state target a DAP config ran (configs are named after
-- their target — dap/launch.lua).
local function getSessionTarget(config)
  local project = config and getProject()
  if project == nil then return nil end
  for _, target in ipairs(project.targets) do
    if target.name == config.name then return target end
  end
  return nil
end

-- A launch with no host to pair with: an executable target.
function M.isStandaloneLaunch(config)
  local target = getSessionTarget(config)
  return target ~= nil and target.kind == 'executable'
end

-- Async capture: the powershell CIM query takes seconds to cold start —
-- vim.fn.system here blocked the main loop for its whole duration
-- (measured 3s), right after every Standalone launch. Polled: one shot at
-- +500ms returned nothing (measured pid=nil, process not yet queryable),
-- leaving Esc-terminate unable to kill the app.
local function capturePid(cmd)
  local attempts = 0
  local function attempt()
    attempts = attempts + 1
    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        local pid = tonumber(vim.trim(table.concat(data, '\n')))
        if pid then
          standalonePid = pid
        elseif attempts < PID_CAPTURE_MAX_ATTEMPTS then
          vim.defer_fn(attempt, PID_CAPTURE_RETRY_MS)
        end
      end,
    })
  end
  attempt()
end

-- Windows: match by process name, not path — a WQL ExecutablePath filter
-- compares literal strings, and the DAP config's forward-slash path never
-- equals Win32's backslash ExecutablePath.
local function getPidQuery(program)
  if is_windows then
    return {
      'powershell', '-NoProfile', '-Command',
      string.format(
        "(Get-Process -Name '%s' -ErrorAction SilentlyContinue | Select-Object -First 1).Id",
        vim.fn.fnamemodify(program, ':t:r')
      ),
    }
  end
  return 'pgrep -f "' .. program .. '"'
end

-- Registers the launch listener that captures the executable's PID so
-- terminate can kill it. Called from dap/dapui_config.setup() at dap load
-- time — must be live before any launch, including manual dap.continue.
function M.registerDapListeners()
  local dap = require('dap')

  dap.listeners.after.launch[STANDALONE_PID_LISTENER_KEY] = function(session, _)
    if M.isStandaloneLaunch(session.config) then
      local program = session.config.program
      vim.defer_fn(function() capturePid(getPidQuery(program)) end, PID_CAPTURE_DELAY_MS)
    end
  end
end

local function killStandalone()
  if standalonePid then
    local pid = standalonePid
    standalonePid = nil
    if is_windows then
      vim.fn.jobstart({ 'taskkill', '/F', '/PID', tostring(pid) })
    else
      vim.fn.jobstart({ 'kill', '-9', tostring(pid) })
    end
  end
end

local function killHost(name)
  if is_windows then
    vim.fn.jobstart({ 'taskkill', '/F', '/IM', name })
  else
    vim.fn.jobstart({ 'killall', name })
  end
end

-- SSOT is the DAP config that actually ran, captured before dap.terminate()
-- clears the session: an executable target kills its captured PID, a plugin
-- target kills the selected host.
local function terminateDap()
  local dap = require('dap')
  local dapui = require('dapui')

  local session = dap.session()
  local config = session and session.config
  local target = getSessionTarget(config)
  local isStandalone = M.isStandaloneLaunch(config)
  dap.terminate()
  dapui.close()

  if isStandalone then
    killStandalone()
  elseif target and getProject().selection.host ~= '' then
    killHost(vim.fs.basename(getProject().selection.host))
  end

  return isStandalone
end

local function killDapThen(continuation)
  local dap = require('dap')

  if dap.session() == nil then
    continuation()
  else
    dap.listeners.after.terminate[BUILD_GUARD_LISTENER_KEY] = function()
      dap.listeners.after.terminate[BUILD_GUARD_LISTENER_KEY] = nil
      vim.defer_fn(continuation, DAP_TERMINATE_GRACE_MS)
    end
    terminateDap()
  end
end

-- traffic.stop() both kills the job and clears its identity, so the job's
-- exit callback never runs — the machine-level replacement for the old
-- per-site isAborted flags. Normal-mode mapping: the log window is a plain
-- buffer, not a terminal.
local function bindAbort(log_buf, log_win)
  vim.keymap.set('n', '<Esc>', function()
    require('core.traffic').stop()
    if vim.api.nvim_win_is_valid(log_win) then
      vim.api.nvim_win_close(log_win, true)
    end
    vim.notify('Aborted', vim.log.levels.WARN)
  end, { buffer = log_buf, nowait = true })
end

-- Closes any previous build-log window and any terminal window — the
-- single-output-window behavior.
local function closeOutputWindows()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buffer = vim.api.nvim_win_get_buf(win)
    if vim.bo[buffer].buftype == 'terminal' or vim.b[buffer].build_log then
      vim.api.nvim_win_close(win, true)
    end
  end
end

-- Opens the build log window: a plain scratch buffer that traffic's
-- onLines batch-appends into — no terminal emulation, so an output burst
-- costs one buffer append per flush tick instead of per-chunk vterm
-- processing and redraws (the measured multi-second stall source).
-- Returns buf, win, and the appendLines handler for traffic.spawn.
local function openLogWindow(height)
  closeOutputWindows()
  vim.cmd('botright ' .. height .. 'split')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  local win = vim.api.nvim_get_current_win()
  vim.b[buf].build_log = true
  vim.bo[buf].bufhidden = 'wipe'
  -- Compile command lines are thousands of characters — wrapped they turn
  -- the log into unnavigable multi-screen blocks.
  vim.wo[win].wrap = false
  -- Validity guards are load-bearing: the job keeps running if the user
  -- closes the log window mid-build (bufhidden=wipe kills the buffer), and
  -- late flush ticks from an aborted job may still arrive — both are
  -- expected states, not errors. Tail-follow only while the window still
  -- shows this buffer.
  local function appendLines(batch)
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, batch)
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
      end
    end
  end
  return buf, win, appendLines
end

-- Failure: highlights applied once, to a now-static buffer — never during
-- the live scroll (see openLogWindow). Errors → quickfix, cursor lands on
-- the first failing source line (never inside the log window — that would
-- swap the log buffer out from under itself). :cn/:cp walk the rest.
local function showBuildFailure(log_buf, log_win, exit_code)
  if vim.api.nvim_buf_is_valid(log_buf) then
    vim.bo[log_buf].modifiable = false
    require('core.autocommands').applyOutputHighlights(log_buf)
    vim.keymap.set('n', 'q', function()
      if vim.api.nvim_win_is_valid(log_win) then
        vim.api.nvim_win_close(log_win, true)
      end
    end, { buffer = log_buf, nowait = true })
    vim.fn.setqflist({}, ' ', {
      title = 'Build',
      lines = vim.api.nvim_buf_get_lines(log_buf, 0, -1, false),
      efm = BUILD_ERRORFORMAT,
    })
    local hasError = false
    for _, item in ipairs(vim.fn.getqflist()) do
      if item.valid == 1 then hasError = true end
    end
    if hasError then
      if vim.api.nvim_get_current_win() == log_win then
        vim.cmd('wincmd p')
      end
      vim.cmd('cfirst')
    end
  end
  vim.notify('Build failed (exit ' .. exit_code .. ') — press q to close', vim.log.levels.ERROR)
end

-- The one job/log-window/errorformat/quickfix machine; core/cast-build.lua
-- supplies the args. on_exit runs on both success and failure: a failing
-- compile after a clean rebuild still reconfigured (fresh
-- compile_commands.json) before the first file ever failed to compile —
-- the project state needs the re-parse regardless. Its listeners refresh
-- .clangd and the root CDB copy; clangd notices the refreshed copy by
-- itself (compilationDatabase.automaticReload).
function M.runBuildJob(args, onSuccess)
  local traffic = require('core.traffic')
  local log_buf, log_win, appendLines = openLogWindow(LOG_WINDOW_HEIGHT)

  local function on_exit(exit_code)
    local project = require('core.project')
    project.parse(project.getRoot())
    if exit_code == 0 then
      if vim.api.nvim_win_is_valid(log_win) then
        vim.api.nvim_win_close(log_win, true)
      end
      onSuccess()
    else
      showBuildFailure(log_buf, log_win, exit_code)
    end
  end

  traffic.spawn(traffic.STATE.BUILDING, args, { onLines = appendLines, onExit = on_exit })
  bindAbort(log_buf, log_win)
end

-- The selection (picker when incomplete) is persisted with this build's
-- configuration before the toolchain runs, so every launch resolves its
-- product against the configuration that was actually built. cast builds
-- every target at once; the selection only decides what to launch
-- afterwards. The build's own on_exit replaces the document, so onBuilt
-- receives the root and reads the fresh state, never a copy held across
-- the build.
local function buildSelected(scheme, onBuilt)
  vim.cmd('silent! wa')
  local project = getProject()
  if project then
    local castBuild = require('core.cast-build')
    local root = project.manifest.root
    local argument = castBuild.TOOLCHAIN_ARGUMENT[scheme]
    require('dap.launch').getOrCreateSelection(project, argument, function()
      castBuild.build(project, argument, function() onBuilt(root) end)
    end)
  else
    vim.notify('No project state here: a project needs project-info.md and cast/CAST.md', vim.log.levels.ERROR)
  end
end

local function launchSelected(root)
  local project = require('core.project').getOrCreate(root)
  local selection = project.selection
  local configuration = require('dap.launch').getConfiguration(project, selection.target)
  if configuration.request == 'attach' then
    vim.notify('Built! Launching ' .. vim.fs.basename(selection.host) .. '...', vim.log.levels.INFO, { timeout = NOTIFY_TIMEOUT_MS })
    vim.fn.jobstart({ selection.host })
  else
    vim.notify('Built! Launching ' .. selection.target .. '...', vim.log.levels.INFO, { timeout = NOTIFY_TIMEOUT_MS })
  end
  vim.defer_fn(function() require('dap').run(configuration) end, LAUNCH_DELAY_MS[configuration.request])
end

local function runBuildAndLaunch(scheme)
  buildSelected(scheme, launchSelected)
end

local function runBuildOnly(scheme)
  buildSelected(scheme, function()
    vim.notify('Built!', vim.log.levels.INFO, { timeout = NOTIFY_TIMEOUT_MS })
  end)
end

-- Every distinct build directory the configurations declare.
local function getBuildDirs(project)
  local dirs, seen = {}, {}
  for _, configuration in pairs(project.configurations) do
    if not seen[configuration.buildDir] then
      seen[configuration.buildDir] = true
      dirs[#dirs + 1] = configuration.buildDir
    end
  end
  return dirs
end

-- cast regeneration is idempotent write-if-different, so clean is simply
-- removing every build directory the configurations declare. The state is
-- re-parsed so its compile section reflects the empty trees. clangd's CDB
-- and index shards live at the project root (core/clangd.lua), so the
-- rm -rf neither destroys the index nor races clangd's open file handles.
local function runClean(onDone)
  local project = getProject()
  if project then
    closeOutputWindows()
    local failed = 0
    for _, dir in ipairs(getBuildDirs(project)) do
      if vim.fn.isdirectory(dir) == 1 and vim.fn.delete(dir, 'rf') ~= 0 then failed = failed + 1 end
    end
    if failed == 0 then
      vim.notify('Clean succeeded', vim.log.levels.INFO)
    else
      vim.notify('Clean failed: ' .. failed .. ' build directories remain', vim.log.levels.ERROR)
    end
    require('core.project').parse(project.manifest.root)
    if onDone then onDone() end
  else
    vim.notify('No project state here: a project needs project-info.md and cast/CAST.md', vim.log.levels.ERROR)
  end
end

-- Keymap-facing entry points. killDapThen composition lives here — lexicon
-- rows stay parameterless dotted references. One flow for every project:
-- the project state decides what is built and launched, never the entry
-- point.

function M.buildDebugAndRun()
  killDapThen(function() runBuildAndLaunch('Debug') end)
end

function M.buildReleaseAndRun()
  killDapThen(function() runBuildAndLaunch('Release') end)
end

function M.buildDebugOnly()
  killDapThen(function() runBuildOnly('Debug') end)
end

function M.buildReleaseOnly()
  killDapThen(function() runBuildOnly('Release') end)
end

function M.cleanBuild()
  killDapThen(function() runClean(function() runBuildAndLaunch('Debug') end) end)
end

function M.cleanOnly()
  killDapThen(runClean)
end

-- F5: pick what to launch — target (auto when the project has one), then
-- host for a plugin target.
function M.configureProject()
  local project = getProject()
  if project then
    require('dap.launch').pick(project, nil, function()
      vim.notify('bb  build debug + run\nbr  build release + run\nbn  build debug only\nbR  build release only')
    end)
  else
    vim.notify('No project state here: a project needs project-info.md and cast/CAST.md', vim.log.levels.ERROR)
  end
end

-- Terminate + close host/app (dispatches on the config that actually ran).
function M.terminateAndNotify()
  if terminateDap() then
    vim.notify('Standalone app terminated')
  end
end

return M
