-- DAP UI configuration
local M = {}

function M.setup()
  local dap = require('dap')
  local dapui = require('dapui')
  local dapConfig = require('dap.configurations')

  -- DAP UI layout
  dapui.setup({
    icons = { expanded = '▾', collapsed = '▸', current_frame = '→' },
    layouts = {
      {
        elements = {
          { id = 'scopes', size = 0.4 },
          { id = 'breakpoints', size = 0.2 },
          { id = 'stacks', size = 0.2 },
          { id = 'watches', size = 0.2 },
        },
        size = 50,
        position = 'left',
      },
      {
        elements = {
          { id = 'repl', size = 0.5 },
          { id = 'console', size = 0.5 },
        },
        size = 12,
        position = 'bottom',
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
    if is_mac then
      local projectType = dapConfig.detectProjectType()
      if projectType == 'plugin' then
        local config = dapConfig.loadDawConfig()
        if config and config.daw then
          hs_call(string.format("require('debug-layout').setupDebugLayout('%s')", config.daw))
        end
      end
    end
  end

  dap.listeners.before.launch.dapui_config = function()
    dapui.open()
    if is_mac then
      local projectType = dapConfig.detectProjectType()
      if projectType == 'plugin' then
        local config = dapConfig.loadDawConfig()
        if config and config.daw then
          hs_call(string.format("require('debug-layout').setupDebugLayout('%s')", config.daw))
        end
      end
    end
  end

  dap.listeners.before.event_terminated.dapui_config = function()
    dapui.close()
    hs_call("require('debug-layout').restoreNormalLayout()")
  end

  dap.listeners.before.event_exited.dapui_config = function()
    dapui.close()
    hs_call("require('debug-layout').restoreNormalLayout()")
  end

  -- Focus nvim pane when breakpoint hit (macOS only — Hammerspoon not on Windows)
  dap.listeners.after.event_stopped.focus_nvim = function()
    hs_call("require('debug-layout').focusNvimPane()")
  end

  -- Float standalone app windows into PaperWM floating layer (macOS only)
  dap.listeners.after.launch.standalone_float = function(session, body)
    if not is_mac then return end
    if dapConfig.detectProjectType() ~= 'standalone' then return end

    local program = session.config.program
    if type(program) == 'function' then program = program() end
    if not program then return end

    local appName = program:match('/([^/]+)%.app/') or program:match('/([^/]+)$')
    if appName then
      vim.defer_fn(function()
        hs_call(string.format("require('debug-layout').floatStandaloneApp('%s')", appName))
      end, 1000)
    end
  end

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

  -- Setup keymaps
  require('core.keymaps').setupDap()
end

return M