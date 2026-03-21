-- Editor options
local M = {}

-- Augment PATH with platform-specific package manager bin directories.
-- Required for external tools (rg, fd, etc.) that plugins resolve via PATH.
-- MacPorts: /opt/local/bin | Homebrew: /opt/homebrew/bin | MSYS2: C:/msys64/mingw64/bin
local function augment_path()
  local is_windows = vim.fn.has('win32') == 1
  local sep = is_windows and ';' or ':'
  local candidates = is_windows
    and { 'C:/msys64/mingw64/bin', 'C:/msys64/usr/bin' }
    or  { '/opt/homebrew/bin', '/usr/local/bin', '/opt/local/bin' }

  for _, dir in ipairs(candidates) do
    local current = vim.env.PATH or ''
    if vim.fn.isdirectory(dir) == 1 and not current:find(dir, 1, true) then
      vim.env.PATH = dir .. sep .. current
    end
  end
end

function M.setup()
  augment_path()

  -- Disable unused providers
  vim.g.loaded_node_provider = 0
  vim.g.loaded_perl_provider = 0
  vim.g.loaded_python3_provider = 0
  vim.g.loaded_ruby_provider = 0

  vim.opt.number = true
  vim.opt.relativenumber = true
  vim.opt.mouse = 'a'
  vim.opt.showmode = false
  vim.opt.breakindent = true
  vim.opt.undofile = true
  vim.opt.ignorecase = true
  vim.opt.smartcase = true
  vim.opt.signcolumn = 'yes'
  vim.opt.updatetime = 250
  vim.opt.timeoutlen = 300
  vim.opt.splitright = true
  vim.opt.splitbelow = true
  vim.opt.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
  vim.opt.inccommand = 'split'
  vim.opt.cursorline = true
  vim.opt.scrolloff = 10
  vim.opt.termguicolors = true
  vim.opt.confirm = true

  vim.schedule(function()
    vim.opt.clipboard = 'unnamedplus'
  end)
end

return M
