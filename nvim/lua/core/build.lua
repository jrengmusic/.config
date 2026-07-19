-- core/build.lua
-- Build + DAP session orchestration. Bodies only — bindings live in
-- core/keymaps.lua (generated from nvim/doc/KEYMAPS.md; rows reference
-- these as @build.*).
--
-- No module-level require('dap'): stopActiveBuildJob() is called from
-- VimLeavePre (core/autocommands.lua) and must not force-load the lazy
-- dap plugin at quit time. All dap/dapui requires stay inside functions.
--
-- Runtime buffer-local keymaps spawned by behavior (bindAbort's terminal
-- <Esc>, the build-failure q-to-close) live here by design — the lexicon
-- covers static bindings only.
local M = {}

local is_windows = vim.fn.has('win32') == 1

-- Build requires MSVC on Windows (JUCE rejects MinGW), so .bat calls vcvarsall.
-- Clean has no compiler dependency, so .sh works everywhere via bash.
local function toMsys(p)
  if is_windows then return p:gsub('\\', '/'):gsub('^(%a):', function(d) return '/' .. d:lower() end) end
  return p
end
local function buildScript() return vim.fn.stdpath('config') .. (is_windows and '\\scripts\\build-debug.bat' or '/scripts/build-debug.sh') end
local function cleanScript() return toMsys(vim.fn.stdpath('config') .. '/scripts/clean-build.sh') end

local DAP_TERMINATE_GRACE_MS = 200
local BUILD_GUARD_LISTENER_KEY = 'build_guard'
local STANDALONE_PID_LISTENER_KEY = 'standalone_pid_capture'

-- Single-flight guard shared by every build/clean job spawn site — stops
-- whatever build/clean job is still running before starting a new one, so
-- two Ninja invocations never race on the same build directory. jobstop on
-- an already-exited id is a documented no-op (same pattern bindAbort uses).
local activeBuildJob = nil
local standalonePid = nil

function M.stopActiveBuildJob()
  if activeBuildJob then
    vim.fn.jobstop(activeBuildJob)
    activeBuildJob = nil
  end
end

-- Registers the launch listener that captures the Standalone app's PID so
-- terminate can kill it. Called from dap/dapui_config.setup() at dap load
-- time — must be live before any launch, including manual dap.continue.
function M.registerDapListeners()
  local dap = require('dap')

  dap.listeners.after.launch[STANDALONE_PID_LISTENER_KEY] = function(session, _)
    -- 'Launch Standalone' is the one config name every no-DAW launch runs
    -- through (pure-app _App target or a plugin project's _Standalone
    -- target alike) — the SSOT for "this session has no DAW to pair with".
    if session.config and session.config.name == 'Launch Standalone' then
      local program = session.config and session.config.program
      if program then
        vim.defer_fn(function()
          if is_windows then
            local result = vim.fn.system({
              'powershell', '-NoProfile', '-Command',
              string.format(
                "Get-CimInstance Win32_Process -Filter \"ExecutablePath='%s'\" | Select-Object -ExpandProperty ProcessId",
                program
              ),
            })
            standalonePid = tonumber(vim.trim(result))
          else
            local result = vim.fn.system('pgrep -f "' .. program .. '"')
            standalonePid = tonumber(vim.trim(result))
          end
        end, 500)
      end
    end
  end
end

-- SSOT is the DAP config that actually ran, captured before dap.terminate()
-- clears the session — not a re-derived "project type". 'Launch Standalone'
-- covers both pure-app and plugin-with-Standalone-format sessions; any
-- 'Attach to DAW (...)' config is the only case that needs a DAW killed.
local function terminateDap()
  local dap = require('dap')
  local dapui = require('dapui')
  local dapConfig = require('dap.configurations')

  local session = dap.session()
  local configName = session and session.config and session.config.name
  dap.terminate()
  dapui.close()

  if configName == 'Launch Standalone' then
    if standalonePid then
      local pid = standalonePid
      standalonePid = nil
      if is_windows then
        vim.fn.jobstart({ 'taskkill', '/F', '/PID', tostring(pid) })
      else
        vim.fn.jobstart({ 'kill', '-9', tostring(pid) })
        vim.fn.system({ '/usr/bin/lsappinfo', 'kill', '-force', tostring(pid) })
      end
    end
  elseif configName and configName:match('^Attach to DAW') then
    local function killDaw(daw)
      if is_windows then
        vim.fn.jobstart({ 'taskkill', '/F', '/IM', daw })
      else
        vim.fn.jobstart({ 'killall', daw })
      end
    end
    local config = dapConfig.loadDawConfig(function(cfg)
      if cfg and cfg.daw then killDaw(cfg.daw) end
    end)
    if config and config.daw then
      killDaw(config.daw)
    end
  end

  return configName == 'Launch Standalone'
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

local function bindAbort(term_buf, term_win, job_id, onAbort)
  vim.keymap.set('t', '<Esc>', function()
    onAbort()
    vim.fn.jobstop(job_id)
    if vim.api.nvim_win_is_valid(term_win) then
      vim.api.nvim_win_close(term_win, true)
    end
    vim.notify('Aborted', vim.log.levels.WARN)
  end, { buffer = term_buf, nowait = true })
end

-- buildFormat resolves the DAW/plugin format, builds it, and hands the
-- resolved cfg to onBuilt — copy-to-system-dir always happens inside the
-- build script itself, so onBuilt only ever decides post-build action
-- (launch, or just notify). Notarize/codesign is dropped: nvim always
-- builds with 'nonotarize'.
local function buildFormat(scheme, onBuilt)
  vim.cmd('silent! wa')

  local dapConfig = require('dap.configurations')
  local root = vim.fn.getcwd()
  local script = buildScript()

  local function runBuildInTerminal(args, onSuccess)
    M.stopActiveBuildJob()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == 'terminal' then
        vim.api.nvim_win_close(win, true)
      end
    end
    vim.cmd('botright 15split')
    local term_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(term_buf)
    local term_win = vim.api.nvim_get_current_win()
    local function on_exit(exit_code)
      if exit_code == 0 then
        if vim.api.nvim_win_is_valid(term_win) then
          vim.api.nvim_win_close(term_win, true)
        end
        -- .clangd sync + LSP restart, and doxygen incremental rebuild, are
        -- both handled by watchers (core/autocommands.lua) — not tied to
        -- build completion. compile_commands.json only changes on a CMake
        -- reconfigure; doxygen sources change every save, so that watcher
        -- is long-debounced instead.
        onSuccess()
      else
        vim.bo[term_buf].modifiable = false
        vim.cmd('stopinsert')
        vim.notify('Build failed (exit ' .. exit_code .. ') — press q to close', vim.log.levels.ERROR)
        vim.keymap.set('n', 'q', function()
          if vim.api.nvim_win_is_valid(term_win) then
            vim.api.nvim_win_close(term_win, true)
          end
        end, { buffer = term_buf, nowait = true })
      end
    end
    local isAborted = false
    local job_id
    if is_windows then
      job_id = vim.fn.jobstart(args, {term = true, on_exit = function(_, exit_code)
        if isAborted then
        else
          on_exit(exit_code)
        end
      end})
    else
      job_id = vim.fn.termopen(args)
      vim.api.nvim_create_autocmd('TermClose', {
        buffer = term_buf, once = true,
        callback = function()
          if isAborted then
          else
            on_exit(vim.v.event.status)
          end
        end,
      })
    end
    activeBuildJob = job_id
    bindAbort(term_buf, term_win, job_id, function() isAborted = true end)
    vim.cmd('startinsert')
  end

  local function args_base(format)
    return {script, root, scheme, format, 'nonotarize'}
  end

  -- One path: resolve the format (cached .nvim-dap-config, or the picker
  -- if absent/invalid — dapConfig.showDawFormatDialog auto-selects when
  -- detectAvailableFormats finds only one), then dispatch on the format
  -- value alone. No project-type branch — Standalone/App-derived builds
  -- and DAW-paired plugin formats both flow through the same dispatch.
  local function go(cfg)
    runBuildInTerminal(args_base(cfg.format), function() onBuilt(cfg) end)
  end
  local config = dapConfig.loadDawConfig(function(cfg) if cfg then go(cfg) end end)
  if config then go(config) end
end

local function runBuildAndLaunch(scheme)
  local dapConfig = require('dap.configurations')

  buildFormat(scheme, function(cfg)
    if cfg.format == 'Standalone' then
      vim.notify('Built! Launching Standalone...', vim.log.levels.INFO, { timeout = 1500 })
      vim.defer_fn(function()
        local dap = require('dap')
        for _, dapCfg in ipairs(dap.configurations.cpp) do
          if dapCfg.name == 'Launch Standalone' then dap.run(dapCfg); return end
        end
        vim.notify('DAP config not found: Launch Standalone', vim.log.levels.ERROR)
      end, 1000)
      return
    end
    local configName = dapConfig.getConfigNameForFormat(cfg.format)
    if is_windows then
      vim.notify('Built! Launching DAW via debugger...', vim.log.levels.INFO, { timeout = 1500 })
      vim.defer_fn(function()
        local dap = require('dap')
        for _, dapCfg in ipairs(dap.configurations.cpp) do
          if dapCfg.name == configName then dap.run(dapCfg); return end
        end
        vim.notify('DAP config not found: ' .. configName, vim.log.levels.ERROR)
      end, 500)
    else
      vim.notify('Built! Launching DAW...', vim.log.levels.INFO, { timeout = 1500 })
      vim.fn.jobstart({ cfg.dawPath })
      vim.defer_fn(function()
        local dap = require('dap')
        for _, dapCfg in ipairs(dap.configurations.cpp) do
          if dapCfg.name == configName then dap.run(dapCfg); return end
        end
        vim.notify('DAP config not found: ' .. configName, vim.log.levels.ERROR)
      end, 2000)
    end
  end)
end

local function runBuildOnly(scheme)
  buildFormat(scheme, function(cfg)
    vim.notify('Built!', vim.log.levels.INFO, { timeout = 1500 })
  end)
end

local function runCleanOnly()
  M.stopActiveBuildJob()
  local root = vim.fn.getcwd()
  local script = cleanScript()
  vim.cmd('botright 20split')
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_buf(buf)
  local function closeTerminal(_, exit_code)
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if exit_code == 0 then
        vim.notify('Clean succeeded', vim.log.levels.INFO)
      else
        vim.notify('Clean failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
      end
      -- Force a redraw: closing a ConPTY-backed (term=true) terminal window
      -- on Windows can leave stale screen content until the next redraw —
      -- the job/window are genuinely done (confirmed via instrumentation),
      -- but the display doesn't reflect it without this.
      vim.cmd('redraw')
    end)
  end
  local isAborted = false
  local job_id
  local function onExit(_, exit_code)
    if isAborted then
      -- skip: abort handler already closed window and notified
    else
      closeTerminal(_, exit_code)
    end
  end
  if is_windows then
    job_id = vim.fn.jobstart({'bash', script, toMsys(root)}, {term = true, on_exit = onExit})
  else
    job_id = vim.fn.termopen({script, root}, {on_exit = onExit})
  end
  activeBuildJob = job_id
  bindAbort(buf, win, job_id, function() isAborted = true end)
  -- No startinsert: clean is non-interactive and the window closes itself
  -- on completion — entering terminal-insert mode right before that close
  -- fires (clean-build finishes in well under a second) leaves nvim stuck
  -- in insert mode on whatever buffer remains, indistinguishable from a hang.
end

local function runCleanThenBuild()
  M.stopActiveBuildJob()
  local root = vim.fn.getcwd()
  local script = cleanScript()
  vim.cmd('botright 20split')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  local win = vim.api.nvim_get_current_win()
  local isAborted = false
  local job_id
  local function onExit(exit_code)
    if isAborted then
      -- skip: abort handler already closed window and notified
    else
      if exit_code == 0 then
        vim.notify('Clean succeeded, running build...', vim.log.levels.INFO)
        runBuildAndLaunch('Debug')
      else
        vim.notify('Clean failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
      end
    end
  end
  if is_windows then
    job_id = vim.fn.jobstart({'bash', script, toMsys(root)}, {term = true, on_exit = function(_, exit_code)
      onExit(exit_code)
    end})
  else
    job_id = vim.fn.termopen({script, root})
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = buf,
      once = true,
      callback = function()
        onExit(vim.v.event.status)
      end,
    })
  end
  activeBuildJob = job_id
  bindAbort(buf, win, job_id, function() isAborted = true end)
  -- No startinsert: same reasoning as runCleanOnly — clean is non-interactive
  -- and closes its own window on completion.
end

-- Keymap-facing entry points. killDapThen composition lives here — lexicon
-- rows stay parameterless dotted references.

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
  killDapThen(runCleanThenBuild)
end

function M.cleanOnly()
  killDapThen(runCleanOnly)
end

-- F5: Show/reconfigure format dialog. Format is the only SSOT — a build
-- producing a single format (e.g. a pure-app project's sole 'Standalone')
-- auto-selects with no DAW question (showDawFormatDialog's #formats==1
-- short-circuit); multi-format builds show the picker as before.
function M.configureProject()
  local dapConfig = require('dap.configurations')

  dapConfig.showDawFormatDialog(function(config)
    if not config then return end
    if config.format == 'Standalone' then
      vim.notify('Standalone:\n  bb  build debug + run\n  br  build release + run\n  bB  build debug only\n  bR  build release only')
    else
      vim.notify('Plugin config saved. Press <leader>br to build.')
    end
  end)
end

-- Terminate + close DAW/App (dispatches on the config that actually ran).
function M.terminateAndNotify()
  if terminateDap() then
    vim.notify('Standalone app terminated')
  end
end

return M
