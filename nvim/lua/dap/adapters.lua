-- DAP adapters configuration
local M = {}

function M.setup()
  local dap = require('dap')
  local is_windows = vim.fn.has('win32') == 1

  if is_windows then
    -- Windows standalone: GDB native DAP (proper GUI launch + stdout capture)
    -- REPLACED BY WHATDBG — testing whatdbg as standalone adapter
    -- local gdbPath = 'C:\\msys64\\mingw64\\bin\\gdb.exe'
    --
    -- if vim.fn.executable(gdbPath) == 1 then
    --   dap.adapters.gdb = {
    --     type = 'executable',
    --     command = gdbPath,
    --     args = {
    --       '--nx',
    --       '--interpreter=dap',
    --       '--init-eval-command', 'set new-console on',
    --       '--init-eval-command', 'set shell off',
    --     },
    --   }
    -- end

    -- Windows: whatdbg (dbgeng-based, reads PDB natively, tracks DLL loads)
    local whatdbgPath = vim.fn.expand('~/.local/bin/whatdbg.exe')

    if vim.fn.executable(whatdbgPath) == 1 then
      dap.adapters.whatdbg = {
        type = 'executable',
        command = whatdbgPath,
      }
    end
  else
    -- macOS: codelldb (LLDB-based, reads DWARF natively)
    local mason_data = vim.fn.stdpath('data') .. '/mason/packages/codelldb'
    local codelldbPath = mason_data .. '/extension/adapter/codelldb'
    local liblldbPath  = mason_data .. '/extension/lldb/lib/liblldb.dylib'

    if vim.fn.executable(codelldbPath) ~= 1 then
      vim.notify('codelldb not found. Run :Mason and install it.', vim.log.levels.WARN)
      return false
    end

    dap.adapters.codelldb = {
      type = 'executable',
      command = codelldbPath,
      args = { '--liblldb', liblldbPath },
    }
  end

  return true
end

return M
