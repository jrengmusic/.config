-- DAP UI configuration
local M = {}

-- The standalone window exists only once the app has created it.
local STANDALONE_FLOAT_DELAY_MS = 1000

function M.setup()
  local dap = require('dap')
  local dapui = require('dapui')

  -- DAP UI layout
  dapui.setup({
    icons = { expanded = '▾', collapsed = '▸', current_frame = '→' },
    layouts = {
      {
        elements = {
          { id = 'scopes', size = 0.5 },
          { id = 'repl',   size = 0.5 },
        },
        size = 15,
        position = 'bottom',
      },
      {
        elements = {
          { id = 'watches',     size = 0.34 },
          { id = 'breakpoints', size = 0.33 },
          { id = 'stacks',      size = 0.33 },
        },
        size = 40,
        position = 'left',
      },
    },
  })

  -- Virtual text for variable values
  require('nvim-dap-virtual-text').setup({
    enabled = true,
    enabled_commands = true,
    highlight_changed_variables = true,
    highlight_new_as_changed = true,
    all_frames = false,
    virt_text_pos = 'eol',
  })

  local is_mac = vim.fn.has('mac') == 1
  local hs = '/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs'
  local function hs_call(expr)
    if is_mac then vim.fn.system(string.format('%s -c "%s"', hs, expr)) end
  end

  -- Auto open/close DAP UI
  dap.listeners.before.attach.dapui_config = function()
    dapui.open()
  end

  dap.listeners.before.launch.dapui_config = function()
    dapui.open()
  end

  dap.listeners.before.event_terminated.dapui_config = function()
    dapui.close()
  end

  dap.listeners.before.event_exited.dapui_config = function()
    dapui.close()
  end

  -- Covers adapters (e.g. whatdbg/dbgeng on Windows) that close the transport
  -- without emitting event_terminated or event_exited.
  dap.listeners.before.disconnect.dapui_config = function()
    dapui.close()
  end

  -- Fires on the outgoing terminate request (e.g. STOP button, dap.terminate()).
  -- Guarantees dapui closes even when the adapter never responds with events.
  dap.listeners.after.terminate.dapui_config = function()
    dapui.close()
  end

  -- dapui hands every session the same console buffer as its terminal. A
  -- terminal job that outlives the session (dap.terminate does not stop the
  -- whatdbg launcher) leaves that buffer a terminal with content, and the
  -- next jobstart(term=true) is rejected. Deleting the buffer at session end
  -- kills the job and makes dapui create a clean console. Attach sessions
  -- have no terminal (term_buf nil); one session fires several of these
  -- events, so the buffer may already be gone.
  local function deleteSessionTerminal(session)
    if session.term_buf ~= nil and vim.api.nvim_buf_is_valid(session.term_buf) then
      vim.api.nvim_buf_delete(session.term_buf, { force = true })
    end
  end

  for _, event in ipairs({ 'event_terminated', 'event_exited', 'disconnect', 'terminate' }) do
    dap.listeners.after[event].delete_session_terminal = deleteSessionTerminal
  end

  -- Focus nvim pane when breakpoint hit (macOS only — Hammerspoon not on Windows)
  dap.listeners.after.event_stopped.focus_nvim = function()
    hs_call("require('debug-layout').focusNvimPane()")
  end

  -- Float standalone app windows into PaperWM floating layer (macOS only)
  -- — same no-host signal core/build.lua's terminateDap() dispatches on.
  dap.listeners.after.launch.standalone_float = function(session, body)
    if is_mac and require('core.build').isStandaloneLaunch(session.config) then
      local program = session.config.program
      if type(program) == 'function' then program = program() end
      local appName = program:match('/([^/]+)%.app/') or program:match('/([^/]+)$')
      if appName then
        vim.defer_fn(function()
          hs_call(string.format("require('debug-layout').floatStandaloneApp('%s')", appName))
        end, STANDALONE_FLOAT_DELAY_MS)
      end
    end
  end

  vim.api.nvim_create_autocmd('TermClose', {
    group = vim.api.nvim_create_augroup('dap-terminal-delete', { clear = true }),
    callback = function(event)
      if vim.b[event.buf]['dap-type'] ~= nil then
        vim.schedule(function()
          -- deleteSessionTerminal may have deleted it at session end.
          if vim.api.nvim_buf_is_valid(event.buf) then
            vim.api.nvim_buf_delete(event.buf, { force = true })
          end
        end)
      end
    end,
  })

  -- Breakpoint signs
  vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DapBreakpoint', linehl = '', numhl = '' })
  vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'DapBreakpointCondition', linehl = '', numhl = '' })
  vim.fn.sign_define('DapBreakpointRejected', { text = '○', texthl = 'DapBreakpointRejected', linehl = '', numhl = '' })
  vim.fn.sign_define('DapStopped', { text = '→', texthl = 'DapStopped', linehl = 'DapStoppedLine', numhl = '' })
  vim.fn.sign_define('DapLogPoint', { text = '◉', texthl = 'DapLogPoint', linehl = '', numhl = '' })

  -- Highlight groups
  vim.api.nvim_set_hl(0, 'DapBreakpoint', { fg = '#e06c75' })
  vim.api.nvim_set_hl(0, 'DapBreakpointCondition', { fg = '#e5c07b' })
  vim.api.nvim_set_hl(0, 'DapBreakpointRejected', { fg = '#5c6370' })
  vim.api.nvim_set_hl(0, 'DapStopped', { fg = '#98c379' })
  vim.api.nvim_set_hl(0, 'DapStoppedLine', { bg = '#2d3319' })
  vim.api.nvim_set_hl(0, 'DapLogPoint', { fg = '#61afef' })

  -- The host process-id listener must be live before any launch, including a
  -- manual dap.continue. The project state's DAP configurations are published
  -- here too, at dap load time.
  require('core.build').registerDapListeners()
  require('dap.launch').setup()

  -- Setup keymaps
  require('core.keymaps').setupDap()
end

return M