-- DAP configuration
return {
  lazy = true,
  keys = {
    { '<leader>dc', desc = 'DAP: Continue' },
    { '<leader>db', desc = 'DAP: Toggle breakpoint' },
    { '<leader>br', desc = 'Build release and run' },
    { '<leader>bb', desc = 'Build debug and run' },
    { '<leader>bR', desc = 'Build release only' },
    { '<leader>bB', desc = 'Build debug only' },
    { '<leader>bc', desc = 'Clean build' },
    { '<leader>bk', desc = 'Clean' },
    { '<F5>', desc = 'Configure project' },
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
