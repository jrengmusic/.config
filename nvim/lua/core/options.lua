-- Editor options
local M = {}

-- Capture the full MSVC dev environment (PATH to cl.exe, INCLUDE, LIB,
-- LIBPATH, WindowsSdkDir, etc.) that vcvarsall.bat x64 sets up. Windows has
-- no system-installed cmake/ninja/cl (build-debug.bat:11-30 sources them
-- this exact way). Lua code that shells out to cmake/ninja directly
-- (dap/configurations.lua:138,147) runs inside nvim's own process and never
-- goes through vcvarsall, so the environment must be captured here instead.
local function msvc_dev_env()
  local vswhere = 'C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe'
  if vim.fn.filereadable(vswhere) ~= 1 then
    return nil
  end

  local vsPath = vim.trim(vim.fn.system({ vswhere, '-latest', '-property', 'installationPath' }))
  if vim.v.shell_error ~= 0 or vsPath == '' then
    return nil
  end

  local vcvarsall = vsPath .. '/VC/Auxiliary/Build/vcvarsall.bat'
  if vim.fn.filereadable(vcvarsall) ~= 1 then
    return nil
  end

  -- Same mechanism as build-debug.bat:27 ("call vcvarsall.bat x64"), plus a
  -- `set` dump so every env var it establishes can be replayed into nvim.
  local probeBat = vim.fn.tempname() .. '.bat'
  vim.fn.writefile({ '@echo off', 'call "' .. vcvarsall .. '" x64 >nul', 'set' }, probeBat)
  local dump = vim.fn.system({ 'cmd.exe', '/c', probeBat })
  vim.fn.delete(probeBat)
  if vim.v.shell_error ~= 0 then
    return nil
  end

  local env = {}
  for line in dump:gmatch('[^\r\n]+') do
    local key, value = line:match('^([^=]+)=(.*)$')
    if key then
      env[key] = value
    end
  end
  return env, vsPath
end

-- Augment PATH with platform-specific package manager bin directories, and
-- on Windows replay the full MSVC dev environment so cmake/ninja/cl resolve
-- the same way they do inside build-debug.bat.
-- Required for external tools (rg, fd, etc.) that plugins resolve via PATH.
-- MacPorts: /opt/local/bin | Homebrew: /opt/homebrew/bin | MSYS2: C:/msys64/mingw64/bin
local function augment_path()
  local is_windows = vim.fn.has('win32') == 1
  local sep = is_windows and ';' or ':'

  if is_windows then
    local devEnv, vsPath = msvc_dev_env()
    if devEnv then
      for key, value in pairs(devEnv) do
        if key:upper() ~= 'PATH' then
          vim.env[key] = value
        end
      end
      vim.env.PATH = devEnv.Path or devEnv.PATH or vim.env.PATH

      -- vcvarsall.bat doesn't put its bundled Ninja on PATH (build-debug.bat:29-30
      -- prepends it explicitly to avoid an MSYS2 ld.exe conflict) — same here.
      local ninjaDir = vsPath .. '/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja'
      if vim.fn.isdirectory(ninjaDir) == 1 then
        vim.env.PATH = ninjaDir .. sep .. vim.env.PATH
      end
    end
  end

  local candidates = is_windows
    and { 'C:/msys64/mingw64/bin', 'C:/msys64/usr/bin' }
    or  { '/opt/homebrew/bin', '/usr/local/bin', '/opt/local/bin' }

  -- Windows: append after the MSVC dev PATH assembled above, so cl.exe
  -- resolves ahead of MSYS2's cc.exe/c++.exe (JUCE rejects MinGW —
  -- keymaps.lua:293). macOS: prepend, giving package-manager bins
  -- precedence over system tools.
  for _, dir in ipairs(candidates) do
    local current = vim.env.PATH or ''
    if vim.fn.isdirectory(dir) == 1 and not current:find(dir, 1, true) then
      vim.env.PATH = is_windows and (current .. sep .. dir) or (dir .. sep .. current)
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
