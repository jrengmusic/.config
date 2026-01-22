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

  -- Auto open/close DAP UI
  dap.listeners.before.attach.dapui_config = function()
    dapui.open()
  end
  dap.listeners.before.launch.dapui_config = function()
    dapui.open()
    -- Setup debug layout when launching
    local config = dapConfig.loadDawConfig()
    if config and config.daw then
      vim.fn.system(string.format('hs -c "require(\'debug-layout\').setupDebugLayout(\'%s\')"', config.daw))
    end
  end
  dap.listeners.before.event_terminated.dapui_config = function()
    dapui.close()
    -- Restore layout when terminated
    vim.fn.system('hs -c "require(\'debug-layout\').restoreNormalLayout()"')
  end
  dap.listeners.before.event_exited.dapui_config = function()
    dapui.close()
    -- Restore layout when exited
    vim.fn.system('hs -c "require(\'debug-layout\').restoreNormalLayout()"')
  end

  -- Focus nvim pane when breakpoint hit
  dap.listeners.after.event_stopped.focus_nvim = function()
    vim.fn.system('hs -c "require(\'debug-layout\').focusNvimPane()"')
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
