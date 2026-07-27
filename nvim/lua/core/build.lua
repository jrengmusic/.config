-- core/build.lua
-- Build + DAP session orchestration. Bodies only — bindings live in
-- core/keymaps.lua (generated from nvim/doc/KEYMAPS.md; rows reference
-- these as @build.*).
--
-- All job spawning/stopping goes through core/traffic.lua — the SSOT state
-- machine that enforces one active build/clean job per session. This module
-- owns only the UI around those jobs (plain log windows fed by traffic's
-- batched onLines — see openLogWindow — notifications, DAP launch
-- sequencing).
--
-- clangd is never touched here: its CDB and index shards live at the
-- project root, outside Builds/ (see core/cmake-picker.syncClangd), so
-- builds and cleans neither contend with its file handles nor require an
-- LSP restart — clangd hot-reloads a reconfigured CDB on its own.
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
-- The freshly launched Standalone process is not always visible to the
-- OS process query on the first attempt — poll until it appears.
local PID_CAPTURE_RETRY_MS = 500
local PID_CAPTURE_MAX_ATTEMPTS = 10

-- Both compiler dialects the build scripts produce: MSVC's
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
          -- Async capture: the powershell CIM query takes seconds to cold
          -- start — vim.fn.system here blocked the main loop for its whole
          -- duration (measured 3s), right after every Standalone launch.
          -- Polled: one shot at +500ms returned nothing (measured pid=nil,
          -- process not yet queryable), leaving Esc-terminate unable to
          -- kill the app.
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
          if is_windows then
            -- Match by process name, not path: a WQL ExecutablePath filter
            -- compares literal strings, and the DAP config's forward-slash
            -- path never equals Win32's backslash ExecutablePath — the
            -- old query could not match anything.
            capturePid({
              'powershell', '-NoProfile', '-Command',
              string.format(
                "(Get-Process -Name '%s' -ErrorAction SilentlyContinue | Select-Object -First 1).Id",
                vim.fn.fnamemodify(program, ':t:r')
              ),
            })
          else
            capturePid('pgrep -f "' .. program .. '"')
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

-- Opens the build/clean log window: a plain scratch buffer that traffic's
-- onLines batch-appends into — no terminal emulation, so an output burst
-- costs one buffer append per flush tick instead of per-chunk vterm
-- processing and redraws (the measured multi-second stall source).
-- Closes any previous build-log window and any terminal window first,
-- same single-output-window behavior the terminal splits had.
-- Returns buf, win, and the appendLines handler for traffic.spawn.
local function openLogWindow(height)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(win)
    if vim.bo[b].buftype == 'terminal' or vim.b[b].build_log then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.cmd('botright ' .. height .. 'split')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  local win = vim.api.nvim_get_current_win()
  vim.b[buf].build_log = true
  vim.bo[buf].bufhidden = 'wipe'
  -- Compile command lines are thousands of characters — wrapped they turn
  -- the log into unnavigable multi-screen blocks (the PTY used to hard-chop
  -- them at terminal width).
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

  -- -1 (vim.fn.getftime's own "doesn't exist" value) when there's no
  -- compile_commands.json yet — a valid, comparable state on its own.
  local function compileDbMtime()
    local compile_db = require('core.cmake-picker').find_compile_db()
    return compile_db ~= nil and vim.fn.getftime(compile_db) or -1
  end

  local function runBuildJob(args, onSuccess)
    local traffic = require('core.traffic')
    local log_buf, log_win, appendLines = openLogWindow(15)
    -- Captured before the job spawns: build-debug.{bat,sh} only reconfigures
    -- (regenerating compile_commands.json) when CMakeCache.txt/build.ninja
    -- are absent — an ordinary incremental build leaves it untouched. Since
    -- CMake configure always runs before compiling (never after), this mtime
    -- has already settled to its post-build value by the time compilation
    -- starts, whether that compilation goes on to succeed or fail.
    local mtimeBefore = compileDbMtime()

    local function on_exit(exit_code)
      -- Runs on both success and failure: a failing compile after a clean
      -- rebuild still reconfigured (fresh compile_commands.json) before the
      -- first file ever failed to compile — the root CDB copy needs the
      -- refresh regardless of whether compilation itself succeeded. An
      -- ordinary incremental build (no reconfigure) leaves compileDbMtime()
      -- unchanged and syncs nothing. clangd notices the refreshed copy by
      -- itself (compilationDatabase.automaticReload) — no LSP restart.
      if compileDbMtime() ~= mtimeBefore then
        require('core.cmake-picker').syncClangdAsync()
      end
      if exit_code == 0 then
        if vim.api.nvim_win_is_valid(log_win) then
          vim.api.nvim_win_close(log_win, true)
        end
        onSuccess()
      else
        -- Highlights applied once, to a now-static buffer — never during
        -- the live scroll (see openLogWindow).
        if vim.api.nvim_buf_is_valid(log_buf) then
          vim.bo[log_buf].modifiable = false
          require('core.autocommands').applyOutputHighlights(log_buf)
          vim.keymap.set('n', 'q', function()
            if vim.api.nvim_win_is_valid(log_win) then
              vim.api.nvim_win_close(log_win, true)
            end
          end, { buffer = log_buf, nowait = true })
          -- Errors → quickfix, cursor lands on the first failing source
          -- line (never inside the log window — that would swap the log
          -- buffer out from under itself). :cn/:cp walk the rest.
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
    end

    traffic.spawn(traffic.STATE.BUILDING, args, { onLines = appendLines, onExit = on_exit })
    bindAbort(log_buf, log_win)
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
    runBuildJob(args_base(cfg.format), function() onBuilt(cfg) end)
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

-- clean-build.sh removes only the Builds tree. clangd's CDB and index
-- shards live at the project root (core/cmake-picker.syncClangd), so the
-- rm -rf neither destroys the index nor races clangd's open file handles —
-- clangd keeps running untouched through a clean.
local function runCleanOnly()
  local traffic = require('core.traffic')
  local root = vim.fn.getcwd()
  local script = cleanScript()

  local log_buf, log_win, appendLines = openLogWindow(20)
  local function on_exit(exit_code)
    if vim.api.nvim_win_is_valid(log_win) then
      vim.api.nvim_win_close(log_win, true)
    end
    if exit_code == 0 then
      vim.notify('Clean succeeded', vim.log.levels.INFO)
    else
      vim.notify('Clean failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
    end
  end
  local cmd = is_windows and { 'bash', script, toMsys(root) } or { script, root }
  traffic.spawn(traffic.STATE.CLEANING, cmd, { onLines = appendLines, onExit = on_exit })
  bindAbort(log_buf, log_win)
end

local function runCleanThenBuild()
  local traffic = require('core.traffic')
  local root = vim.fn.getcwd()
  local script = cleanScript()

  local log_buf, log_win, appendLines = openLogWindow(20)
  local function on_exit(exit_code)
    if exit_code == 0 then
      vim.notify('Clean succeeded, running build...', vim.log.levels.INFO)
      -- runBuildJob's openLogWindow closes this clean log window itself.
      runBuildAndLaunch('Debug')
    else
      vim.notify('Clean failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
    end
  end
  local cmd = is_windows and { 'bash', script, toMsys(root) } or { script, root }
  traffic.spawn(traffic.STATE.CLEANING, cmd, { onLines = appendLines, onExit = on_exit })
  bindAbort(log_buf, log_win)
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
