-- cmake-picker.lua
-- Project-aware picker that groups files by module (like IDE navigators)
local M = {}

local _grep_fixed = true

local SOURCE_EXTENSIONS = {
  'cpp', 'cc', 'c', 'mm', 'm', 'h', 'hpp', 'hxx', 'inl',
  'xml', 'svg', 'json', 'txt', 'md', 'cmake', 'html', 'lua',
  'frag', 'vert',
}

local EXCLUDE_EXTENSIONS = {
  'png', 'jpg', 'jpeg', 'gif', 'bmp', 'ico', 'webp',
  'ttf', 'otf', 'woff', 'woff2',
  'wav', 'mp3', 'aif', 'aiff', 'ogg', 'flac',
  'afdesign', 'psd', 'ai',
  'o', 'obj', 'a', 'so', 'dylib', 'lib', 'dll',
}

local EXCLUDE_DIRS = { 'docs' }

-- Framework module name prefixes, ordered by pick priority.
-- Used by classify_file (path → module name) and by sort priorities.
local FRAMEWORK_PREFIXES = { 'jam', 'kuassa', 'iq', 'juce' }

-- Searches upward from cwd for CMakeLists.txt to find the project root.
-- Falls back to cwd when none is found (e.g. nvim started outside the project).
local function get_project_root()
  local markers = vim.fs.find('CMakeLists.txt', {
    upward = true,
    path   = vim.fn.getcwd(),
    limit  = 1,
  })
  return #markers > 0 and vim.fn.fnamemodify(markers[1], ':h') or vim.fn.getcwd()
end

function M.find_compile_db()
  local root = get_project_root()
  local markers = vim.fs.find('compile_commands.json', {
    path  = root .. '/Builds/Ninja',
    limit = 1,
  })
  return #markers > 0 and markers[1] or nil
end

local function parse_compile_db(compile_db)
  local ok, data = pcall(vim.fn.json_decode, vim.fn.readfile(compile_db))
  if not ok or data == nil then
    return nil
  end
  return data
end

local function get_project_name()
  return vim.fn.fnamemodify(get_project_root(), ':t')
end

local function get_project_dir()
  return get_project_root() .. '/.' .. get_project_name()
end

local function is_symlink_tree_stale()
  local compile_db = M.find_compile_db()
  if compile_db == nil then return false end

  local project_dir = get_project_dir()
  if vim.fn.isdirectory(project_dir) ~= 1 then return true end

  local tree_mtime = vim.fn.getftime(project_dir)
  local db_mtime = vim.fn.getftime(compile_db)

  if db_mtime > tree_mtime then return true end

  local source_dir = get_project_root() .. '/Source'
  if vim.fn.isdirectory(source_dir) == 1 then
    local source_mtime = vim.fn.getftime(source_dir)
    if source_mtime > tree_mtime then return true end
  end

  return false
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

local function is_excluded_dir(name)
  for _, d in ipairs(EXCLUDE_DIRS) do
    if name == d then return true end
  end
  return false
end

local function classify_file(file)
  for _, prefix in ipairs(FRAMEWORK_PREFIXES) do
    local module = file:match('/(' .. prefix .. '_[^/]+)/')
    if module then
      return 'User Modules', module
    end
  end
  if file:find('/Source/') then
    return 'Sources', 'Source'
  end
  return 'Other', nil
end

local function scan_source_dir()
  local source_dir = get_project_root() .. '/Source'
  local files = {}

  if vim.fn.isdirectory(source_dir) ~= 1 then
    return files
  end

  local function scan(dir)
    local entries = vim.fn.readdir(dir)
    for _, entry in ipairs(entries) do
      local path = dir .. '/' .. entry
      if vim.fn.isdirectory(path) == 1 then
        if not is_excluded_dir(entry) then scan(path) end
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
        if not is_excluded_dir(entry) then scan(path, rel) end
      elseif is_source_ext(path) and not is_excluded_ext(path) then
        table.insert(files, { path = path, rel = rel })
      end
    end
  end

  scan(module_path, '')
  return files
end

local function generate_symlink_tree()
  local cwd = get_project_root()
  local project_dir = get_project_dir()
  local compile_db = M.find_compile_db()

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
  vim.fn.mkdir(project_dir .. '/2 User Modules', 'p')

  local seen = {}
  local seen_modules = {}
  local source_root = cwd .. '/Source'

  for _, entry in ipairs(data) do
    local file = entry.file
    if file ~= nil and seen[file] == nil then
      local skip = file:find('/Builds/') ~= nil or file:find('/juce-patched/') ~= nil
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
        elseif group == 'User Modules' and submodule ~= nil then
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
          target_dir = project_dir .. '/2 User Modules/' .. submodule .. '/' .. subdir
        else
          target_dir = project_dir .. '/2 User Modules/' .. submodule
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
  local compile_db = M.find_compile_db()
  local cwd = get_project_root()

  if compile_db == nil and vim.fn.filereadable(cwd .. '/CMakeLists.txt') ~= 1 then
    Snacks.picker.files()
    return
  end

  local clangd_synced = M.syncClangd()

  -- SSOT: Use EXACT same logic as generate_symlink_tree()
  local seen = {}
  local items = {}
  local seen_modules = {}
  local source_root = cwd .. '/Source'

  if compile_db ~= nil then
    local data = parse_compile_db(compile_db)
    if data ~= nil then
      -- First pass: collect from compile_commands.json (same as explorer)
      for i, entry in ipairs(data) do
        local file = entry.file
        if file ~= nil and seen[file] == nil then
          local skip = file:find('/Builds/') ~= nil or file:find('/juce-patched/') ~= nil
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
            elseif group == 'User Modules' and submodule ~= nil then
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
    -- Order: project (CMake/Source) > jam > lib > cium > juce > other
    local MODULE_PRIORITY = {
      CMake = 1,
      Source = 2,
    }
    local function priority(mod)
      if MODULE_PRIORITY[mod] then return MODULE_PRIORITY[mod] end
      for i, prefix in ipairs(FRAMEWORK_PREFIXES) do
        if mod:match('^' .. prefix .. '_') then return i + 2 end
      end
      return #FRAMEWORK_PREFIXES + 3
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
    actions = {
      confirm = function(picker, item)
        picker:close()
        vim.schedule(function()
          vim.cmd('only')
          if clangd_synced then
            for _, client in ipairs(vim.lsp.get_clients()) do
              local bufs = vim.tbl_keys(client.attached_buffers)
              client:stop()
              for _, buf in ipairs(bufs) do
                if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' then
                  vim.defer_fn(function()
                    vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
                  end, 500)
                end
              end
            end
          end
          require('lsp.header-source').ensureCppHeaderLayout(item.file)
        end)
      end,
    },
    win = {
      input = { keys = { ['<CR>'] = { 'confirm', mode = { 'i', 'n' } } } },
      list  = { keys = { ['<CR>'] = 'confirm' } },
    },
  })
end

local function find_symlink_for_file(real_file)
  local cwd = get_project_root()
  local project_dir = get_project_dir()
  local source_root = cwd .. '/Source'

  local group, submodule = classify_file(real_file)
  if group == 'Sources' then
    local rel = real_file:gsub('^' .. vim.pesc(source_root) .. '/', '')
    local subdir = vim.fn.fnamemodify(rel, ':h')
    local basename = vim.fn.fnamemodify(real_file, ':t')
    local symlink
    if subdir ~= '.' and subdir ~= '' then
      symlink = project_dir .. '/1 Source/' .. subdir .. '/' .. basename
    else
      symlink = project_dir .. '/1 Source/' .. basename
    end
    if vim.fn.filereadable(symlink) == 1 then
      return symlink
    end
  elseif group == 'User Modules' and submodule ~= nil then
    local idx = real_file:find('/' .. submodule .. '/')
    if idx ~= nil then
      local module_root = real_file:sub(1, idx + #submodule)
      local rel = real_file:sub(idx + #submodule + 2)
      local symlink = project_dir .. '/2 User Modules/' .. submodule .. '/' .. rel
      if vim.fn.filereadable(symlink) == 1 then
        return symlink
      end
    end
  end
  return nil
end

function M.open_explorer()
  local project_dir = get_project_dir()

  if is_symlink_tree_stale() then
    if not generate_symlink_tree() then
      vim.notify('No compile_commands.json - run cmake first', vim.log.levels.WARN)
      return
    end
  end

  local current_file = vim.fn.expand('%:p')
  local symlink_path = find_symlink_for_file(current_file)

  local Tree = require('snacks.explorer.tree')
  Tree:refresh(project_dir)
  if symlink_path ~= nil then
    Tree:open(symlink_path)
  end

  -- Persistent split sync while explorer is open: fires on every file navigation,
  -- cleared when the explorer closes.
  local _es_group = vim.api.nvim_create_augroup('explorer_split_sync', { clear = true })
  local _es_prev = vim.fn.expand('%:p')
  vim.api.nvim_create_autocmd('BufEnter', {
    group = _es_group,
    callback = function()
      local cur = vim.fn.expand('%:p')
      if cur ~= _es_prev and cur ~= '' then
        _es_prev = cur
        vim.schedule(function()
          require('lsp.header-source').ensureCppHeaderLayout(vim.fn.expand('%:p'))
        end)
      end
    end,
  })

  local picker = require('snacks').picker.explorer({
    cwd = project_dir,
    on_close = function()
      vim.api.nvim_clear_autocmds({ group = 'explorer_split_sync' })
      pcall(function()
        local Tree = require('snacks.explorer.tree')
        Tree:close_all(project_dir)
      end)
    end,
  })

  if symlink_path ~= nil then
    vim.schedule(function()
      pcall(function()
        local Actions = require('snacks.explorer.actions')
        Actions.update(picker, { target = symlink_path, refresh = true })
      end)
    end)
  end
end

-- Regenerates the project's .clangd file from compile_commands.json.
-- Returns (ok, changed): ok is false on failure; changed is true when the
-- written content differs from what was already on disk, so callers can
-- skip an LSP client restart (and the full clangd reindex it triggers)
-- when the compile flags didn't actually change.
function M.syncClangd()
  local compile_db = M.find_compile_db()
  if compile_db == nil then return false, false end

  local data = parse_compile_db(compile_db)
  if data == nil then
    vim.notify('syncClangd: parse failed', vim.log.levels.WARN)
    return false, false
  end

  -- Extract all compiler flags from the first source entry.
  -- Exclude: compiler binary, -o <path>, -c, and the source file itself.
  -- Two-token flags (e.g. -arch arm64) are included as two separate entries.
  local flags = {}
  local seen = {}
  for _, entry in ipairs(data) do
    local cmd = entry.command or ''
    local src = entry.file or ''
    local tokens = vim.split(cmd, '%s+', { trimempty = true })
    local i = 2 -- skip compiler binary (token 1)
    while i <= #tokens do
      local t = tokens[i]
      if t == '-o' then
        i = i + 2
      elseif t == '-c' then
        i = i + 1
      elseif t == src then
        i = i + 1
      elseif t:sub(1, 1) == '-' then
        local next = tokens[i + 1]
        local has_arg = next ~= nil
          and next:sub(1, 1) ~= '-'
          and not t:find('=', 1, true)
          and next ~= src
        local key = has_arg and (t .. ' ' .. next) or t
        if seen[key] == nil then
          seen[key] = true
          table.insert(flags, t)
          if has_arg then table.insert(flags, next) end
        end
        i = i + (has_arg and 2 or 1)
      else
        i = i + 1
      end
    end
    break -- one representative entry is sufficient
  end

  local root = get_project_root()
  local clangd_path = root .. '/.clangd'
  local db_dir = vim.fn.fnamemodify(compile_db, ':h')

  local lines = {
    'CompileFlags:',
    '  CompilationDatabase: ' .. db_dir,
    '  Add:',
  }
  for _, flag in ipairs(flags) do
    table.insert(lines, '    - ' .. flag)
  end
  vim.list_extend(lines, {
    'Diagnostics:',
    '  MissingIncludes: None',
    '  UnusedIncludes: None',
  })

  local old_lines = vim.fn.filereadable(clangd_path) == 1 and vim.fn.readfile(clangd_path) or nil
  local changed = old_lines == nil or table.concat(old_lines, '\n') ~= table.concat(lines, '\n')

  vim.fn.writefile(lines, clangd_path)
  return true, changed
end

function M.regenerate()
  if generate_symlink_tree() then
    M.syncClangd()
    vim.notify('Regenerated project tree + synced .clangd', vim.log.levels.INFO)
  else
    vim.notify('Failed to regenerate - no compile_commands.json', vim.log.levels.ERROR)
  end
end

-- Returns the list of project directories (source root + one root per User Module)
-- derived from compile_commands.json. Each entry is a top-level dir; rg recurses
-- into it, so subdirs must NOT be listed separately to avoid duplicate results.
-- Returns nil when no compile db is found.
local function get_dirs()
  local compile_db = M.find_compile_db()
  if compile_db == nil then return nil end

  local data = parse_compile_db(compile_db)
  if data == nil then return nil end

  local dirs = {}
  local seen_dirs = {}

  -- Source root covers all source files recursively
  local source_root = get_project_root() .. '/Source'
  if vim.fn.isdirectory(source_root) == 1 then
    seen_dirs[source_root] = true
    table.insert(dirs, source_root)
  end

  -- One module_root per User Module (rg recurses into it)
  for _, entry in ipairs(data) do
    local file = entry.file
    if file ~= nil and not file:find('/Builds/') and not file:find('/juce-patched/') then
      local group, submodule = classify_file(file)
      if group == 'User Modules' and submodule ~= nil then
        local idx = file:find('/' .. submodule .. '/')
        if idx ~= nil then
          local module_root = file:sub(1, idx + #submodule)
          if seen_dirs[module_root] == nil then
            seen_dirs[module_root] = true
            table.insert(dirs, module_root)
          end
        end
      end
    end
  end

  -- Sort module dirs: jam first, then lib, cium, juce, other
  if #dirs > 1 then
    local source = table.remove(dirs, 1)
    table.sort(dirs, function(a, b)
      local function dir_priority(d)
        for i, prefix in ipairs(FRAMEWORK_PREFIXES) do
          if d:find('/' .. prefix .. '_') then return i end
        end
        return #FRAMEWORK_PREFIXES + 1
      end
      local pa, pb = dir_priority(a), dir_priority(b)
      if pa ~= pb then return pa < pb end
      return a < b
    end)
    table.insert(dirs, 1, source)
  end

  return #dirs > 0 and dirs or nil
end

function M.grep(seed_search)
  local Snacks = require('snacks')
  local dirs = get_dirs()

  local function toggle_fixed(picker)
    local cur = picker.input.filter.search
    picker:close()
    _grep_fixed = not _grep_fixed
    vim.schedule(function() M.grep(cur) end)
  end

  local opts = {
    title   = 'Grep' .. (_grep_fixed and ' [-F]' or ''),
    actions = { toggle_fixed = toggle_fixed },
    win = {
      input = { keys = { ['<C-f>'] = { 'toggle_fixed', mode = { 'i', 'n' } } } },
      list  = { keys = { ['<C-f>'] = 'toggle_fixed' } },
    },
  }
  if seed_search ~= nil then opts.search = seed_search end
  opts.args = _grep_fixed and { '--glob', '!**/docs/**', '-F' } or { '--glob', '!**/docs/**' }
  if dirs ~= nil       then opts.dirs   = dirs          end
  Snacks.picker.grep(opts)
end

function M.replace_grep(seed_search)
  local Snacks = require('snacks')
  local dirs = get_dirs()

  local function open_replace(picker)
    local search = picker.input.filter.search
    picker:close()
    vim.schedule(function() M.replace(search) end)
  end

  local function toggle_fixed(picker)
    local cur = picker.input.filter.search
    picker:close()
    _grep_fixed = not _grep_fixed
    vim.schedule(function() M.replace_grep(cur) end)
  end

  local picker_opts = {
    title   = 'Grep (then Replace)' .. (_grep_fixed and ' [-F]' or ''),
    live    = true,
    actions = { open_replace = open_replace, toggle_fixed = toggle_fixed },
    win = {
      input = { keys = {
        ['<CR>']  = { 'open_replace', mode = { 'i', 'n' } },
        ['<C-f>'] = { 'toggle_fixed', mode = { 'i', 'n' } },
      }},
      list  = { keys = {
        ['<CR>']  = 'open_replace',
        ['<C-f>'] = 'toggle_fixed',
      }},
    },
  }

  if seed_search ~= nil then picker_opts.search = seed_search end
  picker_opts.args = _grep_fixed and { '--glob', '!**/docs/**', '-F' } or { '--glob', '!**/docs/**' }
  if dirs ~= nil         then picker_opts.dirs   = dirs        end
  Snacks.picker.grep(picker_opts)
end

function M.replace(search)
  local Snacks = require('snacks')
  local dirs = get_dirs()
  local function apply(picker)
    local search      = picker.input.filter.search
    local replacement = vim.trim(picker.input.win:text())
    -- Explicit Tab-selection takes priority; fall back to all visible items.
    local selected = picker:selected()
    if #selected == 0 then selected = picker:items() end
    if #selected == 0 then return end
    picker:close()

    local file_lines = {}
    for _, item in ipairs(selected) do
      -- grep items carry pos = { lnum, col }, not a lnum field
      if item.file and item.pos and item.pos[1] then
        if not file_lines[item.file] then file_lines[item.file] = {} end
        file_lines[item.file][item.pos[1]] = true
      end
    end

    local escaped_s = vim.fn.escape(search,      '/\\')
    local escaped_r = vim.fn.escape(replacement, '/\\&~')
    local file_count = 0

    for file, lnums in pairs(file_lines) do
      local buf = vim.fn.bufadd(file)
      vim.fn.bufload(buf)
      vim.api.nvim_buf_call(buf, function()
        for lnum in pairs(lnums) do
          pcall(vim.cmd, lnum .. 's/\\V' .. escaped_s .. '/' .. escaped_r .. '/gI')
        end
        vim.cmd('update')
      end)
      file_count = file_count + 1
    end

    vim.notify('Replaced "' .. search .. '" → "' .. replacement .. '" in ' .. file_count .. ' file(s)', vim.log.levels.INFO)
  end

  local function toggle_fixed(picker)
    local cur = picker.input.filter.search
    picker:close()
    _grep_fixed = not _grep_fixed
    vim.schedule(function() M.replace(cur) end)
  end

  local picker_opts = {
    title  = 'Replace' .. (_grep_fixed and ' [-F]' or ''),
    search = search ~= nil and search or vim.fn.expand('<cword>'),
    live   = false,
    -- Zero out pattern so the fuzzy matcher never filters the grep results.
    filter = {
      transform = function(_, filter)
        filter.pattern = ''
      end,
    },
    -- Select all items once the initial find completes so the default
    -- is replace-all; Tab deselects individual occurrences before Enter.
    on_show = function(p)
      local function do_select_all()
        if not p.closed then p.list:select_all() end
      end
      if p.matcher.task:running() then
        p.matcher.task:on('done', vim.schedule_wrap(do_select_all))
      else
        vim.schedule(do_select_all)
      end
    end,
    actions = { apply_replace = apply, toggle_fixed = toggle_fixed },
    win = {
      input = { keys = {
        ['<CR>']  = { 'apply_replace', mode = { 'i', 'n' } },
        ['<C-f>'] = { 'toggle_fixed',  mode = { 'i', 'n' } },
      }},
      list  = { keys = {
        ['<CR>']  = 'apply_replace',
        ['<C-f>'] = 'toggle_fixed',
      }},
    },
  }

  picker_opts.args = _grep_fixed and { '--glob', '!**/docs/**', '-F' } or { '--glob', '!**/docs/**' }
  if dirs ~= nil then picker_opts.dirs = dirs      end
  Snacks.picker.grep(picker_opts)
end

return M
