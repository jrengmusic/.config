-- DAP debug configurations for C++/JUCE
-- SSOT for debug configuration management
local M = {}

-- ============================================================================
-- PROJECT TYPE DETECTION
-- ============================================================================

-- Detect if project is plugin or standalone by checking CMakeLists.txt
function M.detectProjectType()
  local root = vim.fn.getcwd()
  
  -- First check: existing config file
  local dawConfig = root .. '/.nvim-dap-config'
  
  if vim.fn.filereadable(dawConfig) == 1 then
    local ok, config = pcall(dofile, dawConfig)
    if ok and config then
      if config.format then
        return 'plugin'  -- Has format field (VST3/AU/etc) = plugin
      elseif config.buildScheme then
        return 'standalone'  -- Only has buildScheme = standalone
      end
    end
  end
  
  -- Second check: CMakeLists.txt content
  local cmakeFile = root .. '/CMakeLists.txt'
  if vim.fn.filereadable(cmakeFile) == 1 then
    local content = table.concat(vim.fn.readfile(cmakeFile), '\n')
    
    -- Check for JUCE plugin markers
    if content:match('juce_add_plugin') or content:match('PLUGIN_') or content:match('VST3') or content:match('AudioUnit') then
      return 'plugin'
    end
    
    -- Check for JUCE standalone app markers
    if content:match('juce_add_console_app') or content:match('juce_add_gui_app') then
      return 'standalone'
    end
  end
  
  -- Third check: build directory structure (check multiple build systems)
  local buildDirs = {
    root .. '/Builds/Ninja',
    root .. '/Builds/Xcode', 
    root .. '/build',
    root .. '/cmake-build-debug'
  }
  
  for _, buildDir in ipairs(buildDirs) do
    -- Check for standalone artefacts
    if vim.fn.isdirectory(buildDir .. '/Debug/Standalone') == 1 or 
       vim.fn.glob(buildDir .. '/*App_artefacts/Debug'):len() > 0 then
      return 'standalone'
    end
    
    -- Check for plugin artefacts
    if vim.fn.isdirectory(buildDir .. '/Debug/VST3') == 1 or 
       vim.fn.isdirectory(buildDir .. '/Debug/AU') == 1 or
       vim.fn.glob(buildDir .. '/*_artefacts/Debug/*.vst3'):len() > 0 or
       vim.fn.glob(buildDir .. '/*_artefacts/Debug/*.component'):len() > 0 then
      return 'plugin'
    end
  end
  
  return nil -- Cannot detect
end

-- ============================================================================
-- CONFIG FILE MANAGEMENT (SSOT)
-- ============================================================================

local function getConfigFilePath()
  return vim.fn.getcwd() .. '/.nvim-dap-config'
end

local function getStandaloneConfigFilePath()
  return vim.fn.getcwd() .. '/.nvim-standalone-config'
end

-- Load .nvim-dap-config as Lua table
-- FAIL FAST = FAIL? FAST FIX!
-- Any problem → IMMEDIATELY show dialog and let user fix
-- Returns config if valid, shows dialog and returns result if invalid
function M.loadDawConfig(callback)
  local configFile = getConfigFilePath()
  
  -- File doesn't exist → show dialog immediately
  if vim.fn.filereadable(configFile) ~= 1 then
    M.showDawFormatDialog(callback)
    return nil
  end
  
  -- File exists but has invalid Lua syntax → delete and show dialog immediately
  local ok, config = pcall(dofile, configFile)
  if not ok then
    vim.notify('DAP config corrupted. Reconfiguring...')
    vim.fn.delete(configFile)
    M.showDawFormatDialog(callback)
    return nil
  end
  
  -- Config returned nil → delete and show dialog immediately
  if not config then
    vim.notify('DAP config empty. Reconfiguring...')
    vim.fn.delete(configFile)
    M.showDawFormatDialog(callback)
    return nil
  end
  
  -- Missing format field → show dialog immediately
  if not config.format or config.format == '' then
    vim.notify('DAP config missing format. Reconfiguring...')
    M.showDawFormatDialog(callback)
    return nil
  end
  
  -- Missing daw field → show dialog immediately
  if not config.daw or config.daw == '' then
    vim.notify('DAP config missing daw. Reconfiguring...')
    M.showDawFormatDialog(callback)
    return nil
  end
  
  -- Missing dawPath field → show dialog immediately
  if not config.dawPath or config.dawPath == '' then
    vim.notify('DAP config missing dawPath. Reconfiguring...')
    M.showDawFormatDialog(callback)
    return nil
  end
  
  -- Invalid dawPath → show dialog immediately
  if vim.fn.filereadable(config.dawPath) ~= 1 then
    vim.notify('DAP config dawPath invalid: ' .. config.dawPath .. '. Reconfiguring...')
    M.showDawFormatDialog(callback)
    return nil
  end
  
  -- Missing buildScheme field → show dialog immediately
  if not config.buildScheme or config.buildScheme == '' then
    vim.notify('DAP config missing buildScheme. Reconfiguring...')
    M.showDawFormatDialog(callback)
    return nil
  end
  
  return config
end

-- Save .nvim-dap-config as Lua table (self-documented)
-- Only fails if write fails (disk full, permissions) - beyond our control
function M.saveDawConfig(format, daw, dawPath, buildScheme)
  local configFile = getConfigFilePath()
  local content = string.format(
    '-- DAP Debug Configuration\n' ..
    '-- Generated by Neovim DAP\n' ..
    'return {\n' ..
    '  format = "%s",        -- Plugin format (VST3, AU, VST, AAX)\n' ..
    '  daw = "%s",           -- DAW name (for display/killall)\n' ..
    '  dawPath = "%s",       -- Absolute path to DAW executable\n' ..
    '  buildScheme = "%s",   -- Build scheme (Debug, Release)\n' ..
    '}',
    format,
    daw,
    dawPath,
    buildScheme
  )
  
  local ok, err = pcall(vim.fn.writefile, vim.split(content, '\n'), configFile)
  if not ok then
    vim.notify('Failed to write DAP config (disk/permissions issue): ' .. tostring(err))
    return false
  end
  
  return true
end

-- Show dialog to configure format, DAW, and build scheme
-- User must provide all fields (validation happens in dialog)
function M.showDawFormatDialog(callback)
  local is_windows = vim.fn.has('win32') == 1

  -- AU is macOS only
  local formats = is_windows and { 'VST3', 'VST', 'AAX' } or { 'VST3', 'AU', 'VST', 'AAX' }

  vim.ui.select(formats, { prompt = 'Select plugin format:' }, function(format)
    if not format then
      vim.notify('DAP config cancelled')
      return
    end

    -- Select build scheme
    local schemes = { 'Debug', 'Release' }
    vim.ui.select(schemes, { prompt = 'Select build scheme:' }, function(buildScheme)
      if not buildScheme then
        vim.notify('DAP config cancelled')
        return
      end

      -- Find DAW executables (OS-specific)
      local apps = {}
      if is_windows then
        -- Use vim.fn.glob — works natively in nvim without shell dependency
        local patterns = {
          'C:/Program Files/*/*.exe',
          'C:/Program Files/*/*/*.exe',
          'C:/Program Files (x86)/*/*.exe',
          'C:/Program Files (x86)/*/*/*.exe',
        }
        for _, pattern in ipairs(patterns) do
          local matches = vim.fn.glob(pattern, false, true)
          for _, path in ipairs(matches) do
            path = path:gsub('\\', '/')
            table.insert(apps, { text = path, file = path })
          end
        end
      else
        local handle = io.popen('find "/Applications" -maxdepth 2 -name "*.app" -type d 2>/dev/null')
        if handle then
          for line in handle:lines() do
            table.insert(apps, { text = line, file = line })
          end
          handle:close()
        end
      end

      if #apps == 0 then
        vim.notify('No applications found')
        return
      end

      Snacks.picker({
        items = apps,
        prompt = 'Select DAW Application: ',
        format = 'file',
        confirm = function(picker, item)
          if not item or not item.file then
            vim.notify('DAP config cancelled: No DAW selected')
            picker:close()
            return
          end

          local dawPath = item.file

          -- macOS: unwrap .app bundle to executable
          if not is_windows and dawPath:match('%.app/?$') then
            local appName = vim.fn.fnamemodify(dawPath, ':t:r')
            dawPath = dawPath:gsub('/$', '') .. '/Contents/MacOS/' .. appName
          end

          -- Verify path exists
          if vim.fn.filereadable(dawPath) ~= 1 then
            vim.notify('DAW executable not found: ' .. dawPath .. '. Try again.')
            picker:close()
            vim.defer_fn(function() M.showDawFormatDialog(callback) end, 100)
            return
          end

          -- Extract DAW name from path
          local daw = vim.fn.fnamemodify(dawPath, ':t')

          -- Save config
          local ok = M.saveDawConfig(format, daw, dawPath, buildScheme)
          if not ok then
            picker:close()
            return
          end

          vim.notify(string.format('DAP config saved: %s + %s (%s)', format, daw, buildScheme))

          if callback then
            callback({ format = format, daw = daw, dawPath = dawPath, buildScheme = buildScheme })
          end

          picker:close()
        end,
      })
    end)
  end)
end

-- ============================================================================
-- DAP CONFIGURATIONS
-- ============================================================================

-- Helper to get DAW PID from config (PLUGIN-ONLY)
local function getDawPid()
  
  -- Check project type - only valid for plugin projects
  local projectType = M.detectProjectType()
  if projectType ~= 'plugin' then
    error('This DAP config is for plugin projects only. Use "Launch Standalone" for standalone apps.')
  end
  
  local config = M.loadDawConfig()
  if not config then
    return nil
  end
  
  local is_windows = vim.fn.has('win32') == 1
  local handle
  if is_windows then
    -- Windows: use tasklist to find PID
    local dawName = vim.fn.fnamemodify(config.daw, ':t:r') -- strip .exe if present
    handle = io.popen('tasklist /FI "IMAGENAME eq ' .. dawName .. '.exe" /FO CSV /NH 2>nul')
  else
    handle = io.popen("pgrep -x '" .. config.daw .. "' 2>/dev/null | head -1")
  end

  if not handle then
    error('Failed to search for DAW process: ' .. config.daw)
  end

  local output = handle:read('*l')
  handle:close()

  if is_windows then
    -- tasklist CSV format: "process.exe","PID","session","session#","mem"
    local pid = output and output:match('"[^"]+","(%d+)"')
    if pid and tonumber(pid) then
      return tonumber(pid)
    end
  else
    if output and tonumber(output) then
      return tonumber(output)
    end
  end

  error('DAW not running: ' .. config.daw .. '. Launch it first.')
end

function M.setup()
  local dap = require('dap')

  -- Standalone: gdb on Windows (GUI launch + stdout), codelldb on Mac
  -- Plugin: codelldb on all platforms (attach to DAW)
  local is_windows = vim.fn.has('win32') == 1
  local standalone_adapter = is_windows and 'gdb' or 'codelldb'
  local plugin_adapter = is_windows and 'whatdbg' or 'codelldb'

  dap.configurations.cpp = {
    {
      name = 'Launch Standalone',
      type = standalone_adapter,
      request = 'launch',
      program = function()
        local root = vim.fn.getcwd()
        -- JUCE standalone apps are in *_App_artefacts/Debug|Release/*.app or *.exe
        local patterns = {
          -- macOS (look for _App_artefacts, not Standalone subdirectory)
          root .. '/Builds/Ninja/*App_artefacts*/Debug/*.app/Contents/MacOS/*',
          root .. '/Builds/Ninja/*App_artefacts*/Release/*.app/Contents/MacOS/*',
          -- Fallback: any artefacts folder with .app directly
          root .. '/Builds/Ninja/*artefacts*/Debug/*.app/Contents/MacOS/*',
          root .. '/Builds/Ninja/*artefacts*/Release/*.app/Contents/MacOS/*',
          -- Windows
          root .. '/Builds/Ninja/*App_artefacts*/Debug/*.exe',
          root .. '/Builds/Ninja/*App_artefacts*/Release/*.exe',
          root .. '/Builds/Ninja/*artefacts*/Debug/*.exe',
          root .. '/Builds/Ninja/*artefacts*/Release/*.exe',
        }
        
        local found = nil
        for _, pattern in ipairs(patterns) do
          local matches = vim.fn.glob(pattern, false, true)
          if #matches > 0 then
            found = matches[1]
            break
          end
        end
        
        if not found then
          vim.notify('Failed to find standalone app in: ' .. root, vim.log.levels.ERROR)
          error('Standalone executable not found. Build project first.')
        end

        return found
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
      args = {},

    },
    {
      name = 'Attach to DAW (VST3)',
      type = plugin_adapter,
      -- Windows: launch DAW through debugger (owns process from birth, tracks all DLL loads)
      -- Mac: attach to already-running DAW
      request = is_windows and 'launch' or 'attach',
      console = 'integratedTerminal',
      pid = not is_windows and getDawPid or nil,
      program = function()
        if is_windows then
          -- Launch mode: program is the DAW executable
          local cfg = require('dap.configurations').loadDawConfig()
          if cfg and cfg.dawPath then return cfg.dawPath end
          error('DAW path not configured. Run F5 to configure.')
        end
        -- Mac: attach mode, program is the plugin binary
        local root = vim.fn.getcwd()
        local patterns = {
          root .. '/Builds/Ninja/*artefacts*/Debug/VST3/*.vst3/Contents/MacOS/*',
          root .. '/Builds/Ninja/*artefacts*/Release/VST3/*.vst3/Contents/MacOS/*',
        }
        for _, pattern in ipairs(patterns) do
          local matches = vim.fn.glob(pattern, false, true)
          if #matches > 0 then return matches[1] end
        end
        error('VST3 plugin not found. Build project first.')
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
    },
    {
      name = 'Attach to DAW (AU)',
      type = plugin_adapter,
      request = 'attach',
      pid = getDawPid,
      program = function()
        local root = vim.fn.getcwd()
        local patterns = {
          -- macOS only (no AU on Windows)
          root .. '/Builds/Ninja/*artefacts*/Debug/AU/*.component/Contents/MacOS/*',
          root .. '/Builds/Ninja/*artefacts*/Release/AU/*.component/Contents/MacOS/*',
        }
        for _, pattern in ipairs(patterns) do
          local matches = vim.fn.glob(pattern, false, true)
          if #matches > 0 then
            return matches[1]
          end
        end
        error('AU plugin not found. Build project first.')
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
    },
    {
      name = 'Attach to DAW (VST)',
      type = plugin_adapter,
      request = 'attach',
      pid = getDawPid,
      program = function()
        local root = vim.fn.getcwd()
        local patterns = {
          -- macOS
          root .. '/Builds/Ninja/*artefacts*/Debug/VST/*.vst/Contents/MacOS/*',
          root .. '/Builds/Ninja/*artefacts*/Release/VST/*.vst/Contents/MacOS/*',
          -- Windows
          root .. '/Builds/Ninja/*artefacts*/Debug/VST/*.dll',
          root .. '/Builds/Ninja/*artefacts*/Release/VST/*.dll',
        }
        for _, pattern in ipairs(patterns) do
          local matches = vim.fn.glob(pattern, false, true)
          if #matches > 0 then
            return matches[1]
          end
        end
        error('VST plugin not found. Build project first.')
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
    },
    {
      name = 'Attach to DAW (AAX)',
      type = plugin_adapter,
      request = 'attach',
      pid = getDawPid,
      program = function()
        local root = vim.fn.getcwd()
        local patterns = {
          -- macOS
          root .. '/Builds/Ninja/*artefacts*/Debug/AAX/*.aaxplugin/Contents/MacOS/*',
          root .. '/Builds/Ninja/*artefacts*/Release/AAX/*.aaxplugin/Contents/MacOS/*',
          -- Windows
          root .. '/Builds/Ninja/*artefacts*/Debug/AAX/*.aaxplugin/Contents/x64/*.aaxplugin',
          root .. '/Builds/Ninja/*artefacts*/Release/AAX/*.aaxplugin/Contents/x64/*.aaxplugin',
        }
        for _, pattern in ipairs(patterns) do
          local matches = vim.fn.glob(pattern, false, true)
          if #matches > 0 then
            return matches[1]
          end
        end
        error('AAX plugin not found. Build project first.')
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
    },
    {
      name = 'Attach to Process',
      type = plugin_adapter,
      request = 'attach',
      pid = require('dap.utils').pick_process,
      cwd = '${workspaceFolder}',
    },
    {
      name = 'Launch Custom Executable',
      type = plugin_adapter,
      request = 'launch',
      program = function()
        return vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file')
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
      args = function()
        local argsStr = vim.fn.input('Arguments: ')
        return vim.split(argsStr, ' ', { trimempty = true })
      end,
    },
  }

  -- Share configurations for C and Objective-C++
  dap.configurations.c = dap.configurations.cpp
  dap.configurations.objcpp = dap.configurations.cpp
end

-- Get DAP configuration name based on format from .nvim-dap-config
function M.getConfigNameForFormat(format)
  local mapping = {
    VST3 = 'Attach to DAW (VST3)',
    AU = 'Attach to DAW (AU)',
    VST = 'Attach to DAW (VST)',
    AAX = 'Attach to DAW (AAX)',
  }
  return mapping[format]
end

-- ============================================================================
-- STANDALONE CONFIG MANAGEMENT
-- ============================================================================

function M.loadStandaloneConfig(callback)
  local configFile = getStandaloneConfigFilePath()
  
  if vim.fn.filereadable(configFile) ~= 1 then
    M.showStandaloneSchemeDialog(callback)
    return nil
  end
  
  
  local ok, config = pcall(dofile, configFile)
  if not ok then
    vim.notify('Standalone config corrupted. Reconfiguring...')
    vim.fn.delete(configFile)
    M.showStandaloneSchemeDialog(callback)
    return nil
  end
  
  if not config or not config.buildScheme or config.buildScheme == '' then
    vim.notify('Standalone config missing buildScheme. Reconfiguring...')
    M.showStandaloneSchemeDialog(callback)
    return nil
  end
  
  return config
end

function M.saveStandaloneConfig(buildScheme)
  local configFile = getStandaloneConfigFilePath()
  local content = string.format(
    '-- Standalone Build Configuration\n' ..
    'return {\n' ..
    '  buildScheme = "%s",\n' ..
    '}',
    buildScheme
  )
  
  local ok = pcall(vim.fn.writefile, vim.split(content, '\n'), configFile)
  if not ok then
    vim.notify('Failed to write standalone config')
    return false
  end
  
  return true
end

function M.showStandaloneSchemeDialog(callback)
  local schemes = { 'Debug', 'Release' }
  
  vim.ui.select(schemes, { prompt = 'Select build scheme:' }, function(buildScheme)
    if not buildScheme then
      vim.notify('Standalone config cancelled')
      return
    end
    
    local ok = M.saveStandaloneConfig(buildScheme)
    if not ok then
      return
    end
    
    vim.notify('Standalone config saved: ' .. buildScheme)
    
    if callback then
      callback({ buildScheme = buildScheme })
    end
  end)
end

return M
