-- DAP configuration
return {
  lazy = true,
  keys = {
    { '<leader>dc', desc = 'DAP: Continue' },
    { '<leader>db', desc = 'DAP: Toggle breakpoint' },
    { '<leader><C-r>', desc = 'Build + Launch + Attach' },
    { '<leader><C-k>', desc = 'Clean + Reconfigure build' },
    { '<F5>', desc = 'DAP: Start/Continue' },
  },
  cmd = { 'DapContinue', 'DapToggleBreakpoint' },
  deps = 'dap',
  setup = function()
    local adaptersOk = require('dap.adapters').setup()
    if not adaptersOk then
      return
    end

    require('dap.configurations').setup()
    require('dap.dapui_config').setup()
  end,
}
