-- DAP adapters configuration
local M = {}

function M.setup()
  local dap = require('dap')

  -- Mason DAP setup - auto-install codelldb
  require('mason-nvim-dap').setup({
    ensure_installed = { 'codelldb' },
    automatic_installation = true,
  })

  -- Refresh Mason registry
  require('mason-registry').refresh()

  -- Get codelldb path from Mason
  local codelldbPath = vim.fn.stdpath('data') .. '/mason/packages/codelldb/extension/adapter/codelldb'

  if vim.fn.executable(codelldbPath) ~= 1 then
    vim.notify('codelldb not found. Run :Mason and install it.', vim.log.levels.WARN)
    return false
  end

  -- Configure codelldb adapter (stdio mode for 1.11.0+)
  dap.adapters.codelldb = {
    type = 'executable',
    command = codelldbPath,
  }

  return true
end

return M
