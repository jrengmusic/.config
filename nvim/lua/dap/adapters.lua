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
  if vim.fn.has('win32') == 1 then
    codelldbPath = codelldbPath .. '.exe'
  end

  if vim.fn.executable(codelldbPath) ~= 1 then
    vim.notify('codelldb not found. Run :Mason and install it.', vim.log.levels.WARN)
    return false
  end

  -- codelldb adapter works on all platforms:
  -- macOS: clang produces DWARF symbols → codelldb/LLDB reads them natively
  -- Windows: clang-cl produces DWARF symbols → codelldb/LLDB reads them natively
  dap.adapters.codelldb = {
    type = 'executable',
    command = codelldbPath,
  }

  return true
end

return M
