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
local HOST_PID_LISTENER_KEY = 'host_pid_capture'

-- The host application's process id, as the adapter itself reports it in the
-- DAP `process` event -- the one authoritative source on both platforms: on
-- macOS the session attaches to the host launchSelected spawned, on Windows
-- whatdbg launches the host under the debugger. Never written to disk: the
-- operating system reuses process ids, so a persisted one outlives its
-- meaning and names an unrelated process on the next boot.
local launchedHostPid = nil

local function getProject()
  local project = require('core.project')
  return project.getOrCreate(project.getRoot())
end

local function getTarget(project, name)
  for _, target in ipairs(project.targets) do
    if target.name == name then return target end
  end
  return nil
end

-- The project-state target a DAP config ran (configs are named after
-- their target — dap/launch.lua).
local function getSessionTarget(config)
  local project = config and getProject()
  if project then return getTarget(project, config.name) end
  return nil
end

-- A target that launches on its own, with no host to pair with.
local function isExecutable(target)
  return target ~= nil and target.kind == 'executable'
end

-- A launch with no host to pair with: an executable target.
function M.isStandaloneLaunch(config)
  return isExecutable(getSessionTarget(config))
end

-- Force-quits the host by exact process id. Pid-exact is the whole point:
-- `killall <name>` and `taskkill /IM <image>` match every running copy of
-- that application, including ones started by hand outside any debug
-- session, and that blast radius is what terminated an unrelated window.
--
-- macOS has no signal that clears the Dock/LaunchServices registration, so
-- this calls the same NSRunningApplication API the Dock's own Force Quit
-- uses. Two JXA details are load-bearing. The singular lookup is
-- runningApplicationWithProcessIdentifier -- the plural, bundle-identifier
-- form is the one that caused the incident. And JXA exposes a no-argument
-- Objective-C method as a property, so `forceTerminate` carries no call
-- parentheses; written as a call it raises TypeError. The nil test names its
-- threat: the host may already have been quit by hand, which leaves the id
-- registered to nothing.
local function killHost(pid)
  if is_windows then
    vim.fn.jobstart({ 'taskkill', '/F', '/PID', tostring(pid) })
  else
    local jxa = string.format(
      [[ObjC.import('AppKit'); var host = $.NSRunningApplication.runningApplicationWithProcessIdentifier(%d); host.isNil() ? false : host.forceTerminate;]],
      pid
    )
    vim.fn.jobstart({ 'osascript', '-l', 'JavaScript', '-e', jxa })
  end
end

-- Registers the listener that records the host's process id. Called from
-- dap/dapui_config.setup() at dap load time -- must be live before any
-- launch, including a manual dap.continue. An executable target needs no
-- id: dap.terminate() stops and reaps the debuggee on its own.
function M.registerDapListeners()
  local dap = require('dap')

  dap.listeners.after.event_process[HOST_PID_LISTENER_KEY] = function(session, body)
    if not M.isStandaloneLaunch(session.config) then
      launchedHostPid = body.systemProcessId
    end
  end
end

-- Kills what `target` launched: the selected host application for a plugin.
-- An executable target needs nothing here -- dap.terminate() stops and reaps
-- the debuggee. A plugin's host is a separate application: launchSelected
-- spawns it and the session attaches on macOS, while on Windows whatdbg
-- launches it under the debugger (core/project/cast.lua, LAUNCH).
local function killTarget(target)
  if target and not isExecutable(target) and launchedHostPid then
    killHost(launchedHostPid)
    launchedHostPid = nil
  end
end

-- What the last launch started, as a project-state target. A live session's
-- own config names exactly what ran, so it answers whenever there is one;
-- once the adapter is gone the state's selection is the only record left.
local function getLaunchedTarget()
  local session = require('dap').session()
  if session then return getSessionTarget(session.config) end
  local project = getProject()
  return project and getTarget(project, project.selection.target)
end

-- dap.terminate() sends the DAP terminate request -- whatdbg advertises
-- supportsTerminateRequest, so nvim-dap takes that path and whatdbg stops
-- and reaps the debuggee itself. The wait is bounded: nvim-dap closes the
-- session on its own timeout, so a wedged adapter costs that timeout and
-- nothing more.
local function terminateDap()
  local dap = require('dap')
  local dapui = require('dapui')
  local target = getLaunchedTarget()

  killTarget(target)

  dap.terminate()
  dapui.close()

  return isExecutable(target)
end

-- Every build and clean entry point starts here: whatever the previous run
-- left running is terminated before the new one starts, so a rebuild never
-- runs beside the process it is about to overwrite. The continuation is timed
-- off the terminate call, never off the adapter's response.
local function killRunningThen(continuation)
  terminateDap()
  vim.defer_fn(continuation, DAP_TERMINATE_GRACE_MS)
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
-- supplies the args. reconfiguresProject names whether this job's target can
-- have touched anything the project locator reads (project-info.md,
-- Builds/, compile_commands.json) -- cast-build.lua's framework-manifest
-- regen stage is pure codegen at the user-module root and never does, so it
-- passes false to avoid a redundant reparse/ProjectChanged/.clangd-copy
-- cycle ahead of the project build stage that actually reconfigures.
-- on_exit reparses on both success and failure when reconfiguresProject is
-- true: a failing compile after a clean rebuild still reconfigured (fresh
-- compile_commands.json) before the first file ever failed to compile — the
-- project state needs the re-parse regardless. Its listeners refresh
-- .clangd and the root CDB copy; clangd notices the refreshed copy by
-- itself (compilationDatabase.automaticReload).
function M.runBuildJob(args, onSuccess, reconfiguresProject)
  local traffic = require('core.traffic')
  local log_buf, log_win, appendLines = openLogWindow(LOG_WINDOW_HEIGHT)

  local function on_exit(exit_code)
    if reconfiguresProject then
      local project = require('core.project')
      project.parse(project.getRoot())
    end
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
    -- The session must attach to the instance this call just started, never
    -- to one already running. The configuration's own pid falls back to a
    -- name match (dap/launch.lua getHostPid), and a name match resolves to
    -- the oldest instance -- the host that was already open before the debug
    -- session, which then gets both the debugger and, at terminate, the
    -- force-quit. jobpid names the process this call created, so it is the
    -- one source that cannot select the wrong instance. The name match stays
    -- correct for the other entry point, where the host is started by hand
    -- and a configuration is picked from dap.continue.
    configuration.pid = vim.fn.jobpid(vim.fn.jobstart({ selection.host }))
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

-- Keymap-facing entry points. killRunningThen composition lives here — lexicon
-- rows stay parameterless dotted references. One flow for every project:
-- the project state decides what is built and launched, never the entry
-- point.

function M.buildDebugAndRun()
  killRunningThen(function() runBuildAndLaunch('Debug') end)
end

function M.buildReleaseAndRun()
  killRunningThen(function() runBuildAndLaunch('Release') end)
end

function M.buildDebugOnly()
  killRunningThen(function() runBuildOnly('Debug') end)
end

function M.buildReleaseOnly()
  killRunningThen(function() runBuildOnly('Release') end)
end

function M.cleanBuild()
  killRunningThen(function() runClean(function() runBuildAndLaunch('Debug') end) end)
end

function M.cleanOnly()
  killRunningThen(runClean)
end

-- F5: pick what to launch — target (auto when the project has one), then
-- host for a plugin target.
function M.configureProject()
  local project = getProject()
  if project then
    require('dap.launch').pick(project, nil, nil)
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
