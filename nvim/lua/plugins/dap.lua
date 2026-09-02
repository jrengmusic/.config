-- DAP configuration
return {
  lazy = true,
  keys = {
    { '<leader>dc', desc = 'DAP: Continue' },
    { '<leader>db', desc = 'DAP: Toggle breakpoint' },
    { '<leader>br', desc = 'Build release and run' },
    { '<leader>bb', desc = 'Build debug and run' },
    { '<leader>bR', desc = 'Build release only' },
    { '<leader>bn', desc = 'Build debug only' },
    { '<leader>bc', desc = 'Clean build' },
    { '<leader>bk', desc = 'Clean' },
    { '<F5>', desc = 'Configure project' },
  },
  cmd = { 'DapContinue', 'DapToggleBreakpoint' },
  deps = 'dap',
  setup = function()
    require('dap.adapters').setup()
    require('dap.dapui_config').setup()
  end,
}
