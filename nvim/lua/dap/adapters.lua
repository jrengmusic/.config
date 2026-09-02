-- DAP adapters configuration: whatdbg on every platform -- standalone
-- launch + host attach, one binary (dbgeng/PDB on Windows, liblldb/DWARF
-- on macOS).
local M = {}

local is_windows = vim.fn.has('win32') == 1
local WHATDBG = vim.fn.expand(is_windows and '~/.local/bin/whatdbg.exe' or '~/.local/bin/whatdbg')

function M.setup()
  local dap = require('dap')
  if vim.fn.executable(WHATDBG) == 1 then
    dap.adapters.whatdbg = {
      type = 'executable',
      command = WHATDBG,
    }
  else
    vim.notify('whatdbg not found at ' .. WHATDBG, vim.log.levels.WARN)
  end
end

return M
