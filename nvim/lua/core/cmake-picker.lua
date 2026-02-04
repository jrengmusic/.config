-- cmake-picker.lua
-- Project-aware picker that groups files by module (like IDE navigators)
local M = {}

local SOURCE_EXTENSIONS = {
  'cpp', 'cc', 'c', 'mm', 'm', 'h', 'hpp', 'hxx',
  'xml', 'svg', 'json', 'txt', 'md', 'cmake',
}

local EXCLUDE_EXTENSIONS = {
  'png', 'jpg', 'jpeg', 'gif', 'bmp', 'ico', 'webp',
  'ttf', 'otf', 'woff', 'woff2',
  'wav', 'mp3', 'aif', 'aiff', 'ogg', 'flac',
  'afdesign', 'psd', 'ai',
  'o', 'obj', 'a', 'so', 'dylib', 'lib', 'dll',
}

local function find_compile_db()
  local cwd = vim.fn.getcwd()
  -- STRICT: Only check Ninja build location - SSOT principle
  local path = 'Builds/Ninja/compile_commands.json'
  local full = cwd .. '/' .. path
  if vim.fn.filereadable(full) == 1 then
    return full
  end
  return nil
end

local function parse_compile_db(compile_db)
  local ok, data = pcall(vim.fn.json_decode, vim.fn.readfile(compile_db))
  if not ok or data == nil then
    return nil
  end
  return data
end

local function get_project_name()
  local cwd = vim.fn.getcwd()
  return vim.fn.fnamemodify(cwd, ':t')
end

local function get_project_dir()
  local cwd = vim.fn.getcwd()
  local name = get_project_name()
  return cwd .. '/.' .. name
end

local function is_source_ext(file)
  local ext = file:match('%.([^%.]+)$')
  if ext == nil then return false end
  ext = ext:lower()
  for _, e in ipairs(SOURCE_EXTENSIONS) do
    if ext == e then return true end
  end
  return false
end

local function is_excluded_ext(file)
  local ext = file:match('%.([^%.]+)$')
  if ext == nil then return false end
  ext = ext:lower()
  for _, e in ipairs(EXCLUDE_EXTENSIONS) do
    if ext == e then return true end
  end
  return false
end

local function classify_file(file)
  if file:find('/Source/') then
    return 'Sources', 'Source'
  elseif file:find('/juce_[^/]+/') then
    return 'JUCE Modules', 'juce_' .. file:match('/juce_([^/]+)/')
  elseif file:find('/kuassa_[^/]+/') then
    return 'JUCE Modules', file:match('/(kuassa_[^/]+)/')
  elseif file:find('/JRENG_[^/]+/') then
    return 'JUCE Modules', file:match('/(JRENG_[^/]+)/')
  elseif file:find('/oblivion_[^/]+/') then
    return 'JUCE Modules', file:match('/(oblivion_[^/]+)/')
  else
    return 'Other', nil
  end
end

local function scan_source_dir()
  local cwd = vim.fn.getcwd()
  local source_dir = cwd .. '/Source'
  local files = {}

  if vim.fn.isdirectory(source_dir) ~= 1 then
    return files
  end

  local function scan(dir)
    local entries = vim.fn.readdir(dir)
    for _, entry in ipairs(entries) do
      local path = dir .. '/' .. entry
      if vim.fn.isdirectory(path) == 1 then
        scan(path)
      elseif is_source_ext(path) and not is_excluded_ext(path) then
        table.insert(files, path)
      end
    end
  end

  scan(source_dir)
  return files
end

local function scan_module_dir(module_path)
  local files = {}
  if vim.fn.isdirectory(module_path) ~= 1 then
    return files
  end

  local function scan(dir, rel_prefix)
    local entries = vim.fn.readdir(dir)
    for _, entry in ipairs(entries) do
      local path = dir .. '/' .. entry
      local rel = rel_prefix == '' and entry or (rel_prefix .. '/' .. entry)
      if vim.fn.isdirectory(path) == 1 then
        scan(path, rel)
      elseif is_source_ext(path) and not is_excluded_ext(path) then
        table.insert(files, { path = path, rel = rel })
      end
    end
  end

  scan(module_path, '')
  return files
end

local function generate_symlink_tree()
  local cwd = vim.fn.getcwd()
  local project_dir = get_project_dir()
  local compile_db = find_compile_db()

  if compile_db == nil then
    return false
  end

  local data = parse_compile_db(compile_db)
  if data == nil then
    return false
  end

  vim.fn.delete(project_dir, 'rf')
  vim.fn.mkdir(project_dir, 'p')
  vim.fn.mkdir(project_dir .. '/1 Source', 'p')
  vim.fn.mkdir(project_dir .. '/2 JUCE Modules', 'p')

  local seen = {}
  local seen_modules = {}
  local source_root = cwd .. '/Source'

  for _, entry in ipairs(data) do
    local file = entry.file
    if file ~= nil and seen[file] == nil then
      local skip = file:find('/Builds/') ~= nil
      if not skip then
        seen[file] = true
        local group, submodule = classify_file(file)

        if group == 'Sources' then
          local rel = file:gsub('^' .. vim.pesc(source_root) .. '/', '')
          local subdir = vim.fn.fnamemodify(rel, ':h')
          local target_dir
          if subdir ~= '.' and subdir ~= '' then
            target_dir = project_dir .. '/1 Source/' .. subdir
          else
            target_dir = project_dir .. '/1 Source'
          end
          vim.fn.mkdir(target_dir, 'p')
          local basename = vim.fn.fnamemodify(file, ':t')
          local symlink = target_dir .. '/' .. basename
          if vim.fn.filereadable(symlink) ~= 1 then
            vim.fn.system({ 'ln', '-sf', file, symlink })
          end
        elseif group == 'JUCE Modules' and submodule ~= nil then
          local idx = file:find('/' .. submodule .. '/')
          if idx ~= nil then
            local module_root = file:sub(1, idx + #submodule)
            if seen_modules[submodule] == nil then
              seen_modules[submodule] = module_root
            end
          end
        end
      end
    end
  end

  for submodule, module_root in pairs(seen_modules) do
    local module_files = scan_module_dir(module_root)
    for _, f in ipairs(module_files) do
      if seen[f.path] == nil then
        seen[f.path] = true
        local subdir = vim.fn.fnamemodify(f.rel, ':h')
        local target_dir
        if subdir ~= '.' and subdir ~= '' then
          target_dir = project_dir .. '/2 JUCE Modules/' .. submodule .. '/' .. subdir
        else
          target_dir = project_dir .. '/2 JUCE Modules/' .. submodule
        end
        vim.fn.mkdir(target_dir, 'p')
        local basename = vim.fn.fnamemodify(f.path, ':t')
        local symlink = target_dir .. '/' .. basename
        if vim.fn.filereadable(symlink) ~= 1 then
          vim.fn.system({ 'ln', '-sf', f.path, symlink })
        end
      end
    end
  end

  local source_files = scan_source_dir()
  for _, file in ipairs(source_files) do
    if seen[file] == nil then
      seen[file] = true
      local rel = file:gsub('^' .. vim.pesc(source_root) .. '/', '')
      local subdir = vim.fn.fnamemodify(rel, ':h')
      local target_dir
      if subdir ~= '.' and subdir ~= '' then
        target_dir = project_dir .. '/1 Source/' .. subdir
      else
        target_dir = project_dir .. '/1 Source'
      end
      vim.fn.mkdir(target_dir, 'p')
      local basename = vim.fn.fnamemodify(file, ':t')
      local symlink = target_dir .. '/' .. basename
      if vim.fn.filereadable(symlink) ~= 1 then
        vim.fn.system({ 'ln', '-sf', file, symlink })
      end
    end
  end

  return true
end

function M.files()
  local Snacks = require('snacks')
  local compile_db = find_compile_db()

  if compile_db == nil then
    Snacks.picker.files()
    return
  end

  local data = parse_compile_db(compile_db)
  if data == nil then
    Snacks.picker.files()
    return
  end

  -- SSOT: Use EXACT same logic as generate_symlink_tree()
  local seen = {}
  local items = {}
  local cwd = vim.fn.getcwd()
  local seen_modules = {}
  local source_root = cwd .. '/Source'

  -- First pass: collect from compile_commands.json (same as explorer)
  for i, entry in ipairs(data) do
    local file = entry.file
    if file ~= nil and seen[file] == nil then
      local skip = file:find('/Builds/') ~= nil
      if not skip then
        seen[file] = true
        local group, submodule = classify_file(file)

        if group == 'Sources' then
          local display = file:gsub('^' .. vim.pesc(cwd) .. '/', '')
          table.insert(items, {
            idx = i,
            score = i,
            text = 'Source/' .. display,
            file = file,
            module = 'Source',
            display = display,
          })
        elseif group == 'JUCE Modules' and submodule ~= nil then
          local idx = file:find('/' .. submodule .. '/')
          if idx ~= nil then
            local module_root = file:sub(1, idx + #submodule)
            if seen_modules[submodule] == nil then
              seen_modules[submodule] = module_root
            end
          end
          local display = file:gsub('^' .. vim.pesc(cwd) .. '/', '')
          table.insert(items, {
            idx = i,
            score = i,
            text = submodule .. '/' .. display,
            file = file,
            module = submodule,
            display = display,
          })
        end
      end
    end
  end

  -- Second pass: scan ALL files from discovered modules (same as explorer)
  for submodule, module_root in pairs(seen_modules) do
    local module_files = scan_module_dir(module_root)
    for _, f in ipairs(module_files) do
      if seen[f.path] == nil then
        seen[f.path] = true
        local display = f.path:gsub('^' .. vim.pesc(cwd) .. '/', '')
        table.insert(items, {
          idx = #items + 1,
          score = #items + 1,
          text = submodule .. '/' .. display,
          file = f.path,
          module = submodule,
          display = display,
        })
      end
    end
  end

  -- Third pass: scan ALL Source files (same as explorer)
  local source_files = scan_source_dir()
  for _, file in ipairs(source_files) do
    if seen[file] == nil then
      seen[file] = true
      local display = file:gsub('^' .. vim.pesc(cwd) .. '/', '')
      table.insert(items, {
        idx = #items + 1,
        score = #items + 1,
        text = 'Source/' .. display,
        file = file,
        module = 'Source',
        display = display,
      })
    end
  end

  -- Fourth pass: add CMakeLists.txt from project root
  local cmake_file = cwd .. '/CMakeLists.txt'
  if vim.fn.filereadable(cmake_file) == 1 and seen[cmake_file] == nil then
    seen[cmake_file] = true
    table.insert(items, {
      idx = #items + 1,
      score = #items + 1,
      text = 'CMakeLists.txt',
      file = cmake_file,
      module = 'CMake',
      display = 'CMakeLists.txt',
    })
  end

  table.sort(items, function(a, b)
    if a.module == b.module then
      return a.display < b.display
    end
    -- Order: exact matches first, then prefixes, then others
    local MODULE_ORDER = { 'CMake', 'Source', 'kuassa_', 'bo_', 'juce_' }
    local function priority(mod)
      for i, pattern in ipairs(MODULE_ORDER) do
        if mod == pattern or mod:match('^' .. pattern) then
          return i
        end
      end
      return #MODULE_ORDER + 1
    end
    local pa, pb = priority(a.module), priority(b.module)
    if pa ~= pb then return pa < pb end
    return a.module < b.module
  end)

  for i, item in ipairs(items) do
    item.idx = i
    item.score = i
  end

  Snacks.picker({
    items = items,
    source = 'cmake_project',
    format = function(item, picker)
      return {
        { item.module .. '/', 'DiagnosticInfo' },
        { item.display, 'Normal' },
      }
    end,
  })
end

function M.open_explorer()
  local project_dir = get_project_dir()

  if vim.fn.isdirectory(project_dir) ~= 1 or vim.fn.empty(vim.fn.readdir(project_dir)) == 1 then
    if not generate_symlink_tree() then
      vim.notify('No compile_commands.json - run cmake first', vim.log.levels.WARN)
      return
    end
  end

  require('snacks').picker.explorer({ cwd = project_dir })
end

function M.regenerate()
  if generate_symlink_tree() then
    vim.notify('Regenerated project tree', vim.log.levels.INFO)
  else
    vim.notify('Failed to regenerate - no compile_commands.json', vim.log.levels.ERROR)
  end
end

function M.grep()
  local Snacks = require('snacks')
  local compile_db = find_compile_db()

  if compile_db == nil then
    Snacks.picker.grep()
    return
  end

  local data = parse_compile_db(compile_db)
  if data == nil then
    Snacks.picker.grep()
    return
  end

  -- SSOT: Use EXACT same logic as M.files() for directory discovery
  local seen_dirs = {}
  local dirs = {}
  local cwd = vim.fn.getcwd()
  local seen_modules = {}
  local source_root = cwd .. '/Source'

  -- First pass: collect directories from compile_commands.json
  for _, entry in ipairs(data) do
    local file = entry.file
    if file ~= nil then
      local skip = file:find('/Builds/') ~= nil
      if not skip then
        local group, submodule = classify_file(file)

        if group == 'Sources' then
          local dir = vim.fn.fnamemodify(file, ':h')
          if seen_dirs[dir] == nil then
            seen_dirs[dir] = true
            table.insert(dirs, dir)
          end
        elseif group == 'JUCE Modules' and submodule ~= nil then
          local idx = file:find('/' .. submodule .. '/')
          if idx ~= nil then
            local module_root = file:sub(1, idx + #submodule)
            if seen_modules[submodule] == nil then
              seen_modules[submodule] = module_root
              -- Add module root directory
              if seen_dirs[module_root] == nil then
                seen_dirs[module_root] = true
                table.insert(dirs, module_root)
              end
            end
          end
          -- Also add the file's directory
          local dir = vim.fn.fnamemodify(file, ':h')
          if seen_dirs[dir] == nil then
            seen_dirs[dir] = true
            table.insert(dirs, dir)
          end
        end
      end
    end
  end

  -- Second pass: scan ALL directories from discovered modules
  for submodule, module_root in pairs(seen_modules) do
    local module_files = scan_module_dir(module_root)
    for _, f in ipairs(module_files) do
      local dir = vim.fn.fnamemodify(f.path, ':h')
      if seen_dirs[dir] == nil then
        seen_dirs[dir] = true
        table.insert(dirs, dir)
      end
    end
  end

  -- Third pass: scan ALL Source directories
  local source_files = scan_source_dir()
  for _, file in ipairs(source_files) do
    local dir = vim.fn.fnamemodify(file, ':h')
    if seen_dirs[dir] == nil then
      seen_dirs[dir] = true
      table.insert(dirs, dir)
    end
  end

  if #dirs == 0 then
    Snacks.picker.grep()
    return
  end

  Snacks.picker.grep({ dirs = dirs })
end

return M
