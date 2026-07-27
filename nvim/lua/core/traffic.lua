-- core/traffic.lua
-- SSOT state machine for external process traffic: every build/clean job in
-- the session flows through here. One state variable, one job handle — the
-- machine enforces the single-active-job invariant that was previously
-- scattered across per-spawn-site guards (activeBuildJob, isAborted flags).
--
-- LSP is deliberately absent from this machine: clangd runs continuously
-- for the whole session. Its compilation database lives at the project
-- root (core/cmake-picker.syncClangd) so the index shards sit outside
-- Builds/ — a clean can't destroy them or race clangd's file handles, and
-- clangd hot-reloads a reconfigured CDB by itself. Nothing here ever needs
-- to stop or restart an LSP client.
local M = {}

-- Output batching: piped job output is coalesced and delivered to the
-- caller at most once per FLUSH_MS, so a compiler error burst costs one
-- buffer append per tick instead of a redraw per chunk. No PTY anywhere:
-- terminal emulation (ConPTY/vterm parsing, per-chunk redraw, live match
-- highlighting) was the measured source of multi-second main-loop stalls
-- during MSVC output bursts; a plain pipe has none of it, and ninja
-- detects the non-TTY and emits plain per-edge lines at the source.
local FLUSH_MS = 100

M.STATE = { IDLE = 'IDLE', BUILDING = 'BUILDING', CLEANING = 'CLEANING' }

local state = M.STATE.IDLE
local jobId = nil

function M.state() return state end

-- Stops whatever job is running and returns the machine to IDLE. jobstop on
-- an already-exited id is a documented no-op, so this is safe to call from
-- every spawn site and from VimLeavePre alike. Clearing jobId here is what
-- makes a superseded/aborted job's exit callback a no-op (see spawn below):
-- job identity, not a boolean flag, decides whether an exit is still live.
function M.stop()
  if jobId then
    vim.fn.jobstop(jobId)
  end
  jobId = nil
  state = M.STATE.IDLE
end

-- Single spawn gate. Transitions IDLE -> nextState, runs cmd as a plain
-- piped job (no PTY — see FLUSH_MS above), and calls back on handlers:
--   handlers.onLines(batch) — coalesced output lines (stdout+stderr merged,
--     CR stripped), at most once per FLUSH_MS plus a final flush at exit
--   handlers.onExit(exit_code) — back in IDLE, after the final flush
-- Both fire only while this job is still the machine's current job. A job
-- that was stopped (aborted, superseded by a newer request, or killed at
-- quit) exits silently: its handlers never run, matching the previous
-- isAborted semantics without the per-site flag. One code path for both
-- platforms — the old jobstart-term/termopen branch existed only for
-- terminal wiring, which is gone.
-- Returns the job id; callers wire abort keymaps via M.stop().
function M.spawn(nextState, cmd, handlers)
  M.stop()
  state = nextState

  local thisJob
  local pendingChunk = ''
  local pendingLines = {}
  local flushTimer = assert(vim.uv.new_timer())

  local function flush()
    if #pendingLines > 0 then
      local batch = pendingLines
      pendingLines = {}
      handlers.onLines(batch)
    end
  end

  -- jobstart stream convention: data[1] continues the previous chunk's
  -- partial line, data[#data] is the new partial remainder ('' on a clean
  -- line break). CR stripped: piped .bat/cl.exe output is CRLF-terminated.
  local function collect(data)
    data[1] = pendingChunk .. data[1]
    pendingChunk = table.remove(data)
    for _, line in ipairs(data) do
      table.insert(pendingLines, (line:gsub('\r$', '')))
    end
  end

  local function exitGate(exit_code)
    flushTimer:stop()
    flushTimer:close()
    if jobId == thisJob then
      jobId = nil
      state = M.STATE.IDLE
      if pendingChunk ~= '' then
        table.insert(pendingLines, (pendingChunk:gsub('\r$', '')))
        pendingChunk = ''
      end
      flush()
      handlers.onExit(exit_code)
    end
  end

  thisJob = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data then collect(data) end
    end,
    on_stderr = function(_, data)
      if data then collect(data) end
    end,
    on_exit = function(_, exit_code)
      exitGate(exit_code)
    end,
  })
  flushTimer:start(FLUSH_MS, FLUSH_MS, vim.schedule_wrap(flush))
  jobId = thisJob
  return thisJob
end

return M
