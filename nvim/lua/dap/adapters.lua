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
    -- macOS: whatdbg (standalone adapter, same binary as Windows, no .exe)
    local whatdbgPath = vim.fn.expand('~/.local/bin/whatdbg')

    if vim.fn.executable(whatdbgPath) == 1 then
      dap.adapters.whatdbg = {
        type = 'executable',
        command = whatdbgPath,
      }
    end
  end

  return true
end

return M
