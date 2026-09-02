-- core/navigator.lua
-- Project navigator: file picker grouped by module (like IDE navigators),
-- project explorer over a symlink tree, and project-scoped grep/replace.
-- One walk (getTrees -> getEntries) feeds every sink: the picker items,
-- the symlink tree, the grep directory list. Project facts (root, JUCE
-- root, compile database) come from the project state (core/project.lua);
-- outside a project the pickers fall back to the plain cwd pickers.
local M = {}

local function get_project()
  local project = require('core.project')
  return project.getOrCreate(project.getRoot())
end

local isGrepFixed = true

local SOURCE_EXTENSIONS = {
  'cpp', 'cc', 'c', 'mm', 'm', 'h', 'hpp', 'hxx', 'inl',
  'xml', 'svg', 'json', 'txt', 'md', 'cmake', 'html', 'css', 'lua',
  'frag', 'vert', 'cast',
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
-- Used by getSubmodule (path -> module name) and by sort priorities.
local FRAMEWORK_PREFIXES = { 'jam', 'kuassa', 'iq', 'juce' }

-- Framework roots (jam/, ___lib___/, ___cium___/) keep curated/generated
-- content dirs as siblings of their <prefix>_* module dirs (e.g.
-- .../dev/jam/cast and .../dev/jam/generated next to .../dev/jam/jam_core).
-- Each is a virtual submodule <prefix>_<siblingName> so it sorts and
-- displays alongside that framework's other modules.
local FRAMEWORK_SIBLING_DIRS = { 'cast', 'generated' }

-- Explorer tree folders, one per entry group.
local TREE_FOLDER = { Source = '1 Source', module = '2 User Modules', Cast = '3 Cast' }

-- Project-root files that belong to no scanned directory tree. Each becomes a
-- picker item under its own module label; the order here is the pick order.
local ROOT_FILES = {
  { name = 'project-info.md', module = 'Project' },
  { name = 'CMakeLists.txt',  module = 'CMake'   },
}

-- Picker order: project (Project/CMake/Source/Cast) > jam > lib > cium > juce > other
local MODULE_PRIORITY = {
  Project = 1,
  CMake = 2,
  Source = 3,
  Cast = 4,
}

local GREP_ARGS = { '--glob', '!**/docs/**' }
local GREP_ARGS_FIXED = { '--glob', '!**/docs/**', '-F' }

-- Project state root; cwd outside a project (the pickers then have no
-- module tree to group).
local function get_project_root()
  local project = get_project()
  return project and project.manifest.root or require('core.project').getRoot()
end

-- The project state's JUCE root, or nil outside a project.
local function get_juce_path()
  local project = get_project()
  return project and project.dependencies.juce.root or nil
end

-- A compile-database entry under a configuration's build directory is
-- generated (BinaryData, JuceLibraryCode), not authored source.
local function isGenerated(file)
  for _, configuration in pairs(get_project().configurations) do
    if file:sub(1, #configuration.buildDir + 1) == configuration.buildDir .. '/' then return true end
  end
  return false
end

-- The <prefix>_<name> submodule a path belongs to, or nil.
local function getSubmodule(file)
  for _, prefix in ipairs(FRAMEWORK_PREFIXES) do
    local module = file:match('/(' .. prefix .. '_[^/]+)/')
    if module then return module end
  end
  return nil
end

-- Resolves the directory a discovered <prefix>_<name> submodule should be
-- scanned from. JUCE is copied into an ephemeral OS-temp tree before
-- patching (jam/kuassa BuildSetup.cmake PATCHED_JUCE_PATH) — CDB entries for
-- juce_* submodules point there, not at the permanent checkout, and that
-- tree is deleted and rebuilt on the next configure. Redirect juce_*
-- submodules to the pristine JUCE_PATH so the picker shows editable,
-- permanent source instead of a disposable copy.
local function resolve_module_root(file, submodule)
  local idx = file:find('/' .. submodule .. '/')
  if idx == nil then return nil end
  if submodule:match('^juce_') then
    local juce_path = get_juce_path()
    if juce_path == nil then return nil end
    return juce_path .. '/modules/' .. submodule
  end
  return file:sub(1, idx + #submodule)
end

-- The project state's compile database for the selected configuration
-- (else the first built one), or nil outside a project / before the first
-- build.
function M.find_compile_db()
  local project = get_project()
  local compile = project and require('core.project').getCompile(project)
  return compile and compile.database or nil
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

  local cast_dir = get_project_root() .. '/cast'
  if vim.fn.isdirectory(cast_dir) == 1 then
    local cast_mtime = vim.fn.getftime(cast_dir)
    if cast_mtime > tree_mtime then return true end
  end

  return false
end

local function has_extension(file, extensions)
  local ext = file:match('%.([^%.]+)$')
  if ext == nil then return false end
  ext = ext:lower()
  for _, e in ipairs(extensions) do
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

-- Every source file under root, as { path, relative }, depth-first.
local function scan_dir(root)
  local files = {}
  local function scan(dir, rel_prefix)
    for _, entry in ipairs(vim.fn.readdir(dir)) do
      local path = dir .. '/' .. entry
      local rel = rel_prefix == '' and entry or (rel_prefix .. '/' .. entry)
      if vim.fn.isdirectory(path) == 1 then
        if not is_excluded_dir(entry) then scan(path, rel) end
      elseif has_extension(path, SOURCE_EXTENSIONS) and not has_extension(path, EXCLUDE_EXTENSIONS) then
        files[#files + 1] = { path = path, relative = rel }
      end
    end
  end
  if vim.fn.isdirectory(root) == 1 then scan(root, '') end
  return files
end

-- The user-module roots the compile database names, submodule -> root.
local function getModuleRoots()
  local roots = {}
  local compile_db = M.find_compile_db()
  local data = compile_db and parse_compile_db(compile_db) or {}
  for _, entry in ipairs(data) do
    local file = entry.file
    local submodule = file and not isGenerated(file) and getSubmodule(file)
    if submodule and roots[submodule] == nil then
      roots[submodule] = resolve_module_root(file, submodule)
    end
  end
  return roots
end

local function getFrameworkSiblings(moduleRoots)
  local siblings, seen = {}, {}
  for submodule, module_root in pairs(moduleRoots) do
    local prefix = submodule:match('^(%a+)_')
    local framework_root = vim.fn.fnamemodify(module_root, ':h')
    for _, sibling in ipairs(FRAMEWORK_SIBLING_DIRS) do
      local dir = framework_root .. '/' .. sibling
      if seen[dir] == nil and vim.fn.isdirectory(dir) == 1 then
        seen[dir] = true
        siblings[#siblings + 1] = { module = prefix .. '_' .. sibling, dir = dir }
      end
    end
  end
  table.sort(siblings, function(a, b) return a.dir < b.dir end)
  return siblings
end

-- Every directory tree the navigator covers, in display order: the
-- project's Source and cast trees, one tree per user module the compile
-- database names, and each framework's curated sibling dirs. Each tree
-- knows its picker module label and its explorer folder (sub = the
-- module's own folder inside the group folder).
local function getTrees()
  local root = get_project_root()
  local trees = {}
  local function add(dir, module, folder, sub)
    if vim.fn.isdirectory(dir) == 1 then
      trees[#trees + 1] = { dir = dir, module = module, folder = folder, sub = sub }
    end
  end
  add(root .. '/Source', 'Source', TREE_FOLDER.Source)
  add(root .. '/cast', 'Cast', TREE_FOLDER.Cast)

  local moduleRoots = getModuleRoots()
  local submodules = vim.tbl_keys(moduleRoots)
  table.sort(submodules)
  for _, submodule in ipairs(submodules) do
    if moduleRoots[submodule] then add(moduleRoots[submodule], submodule, TREE_FOLDER.module, submodule) end
  end
  for _, sibling in ipairs(getFrameworkSiblings(moduleRoots)) do
    add(sibling.dir, sibling.module, TREE_FOLDER.module, sibling.module)
  end
  return trees
end

-- Every navigable file, once: { file, module, display, link } per tree
-- file (link = its path inside the explorer tree), plus the root files
-- (picker only, no link).
local function getEntries()
  local root = get_project_root()
  local entries, seen = {}, {}
  local function add(file, module, link)
    if seen[file] == nil then
      seen[file] = true
      entries[#entries + 1] = { file = file, module = module, display = file:gsub('^' .. vim.pesc(root) .. '/', ''), link = link }
    end
  end
  for _, tree in ipairs(getTrees()) do
    local prefix = tree.folder .. '/' .. (tree.sub and (tree.sub .. '/') or '')
    for _, scanned in ipairs(scan_dir(tree.dir)) do
      add(scanned.path, tree.module, prefix .. scanned.relative)
    end
  end
  for _, root_file in ipairs(ROOT_FILES) do
    local path = root .. '/' .. root_file.name
    if vim.fn.filereadable(path) == 1 then add(path, root_file.module, nil) end
  end
  return entries
end

-- Rebuilds the explorer's symlink tree from the entries.
local function generate_symlink_tree(entries)
  local project_dir = get_project_dir()
  vim.fn.delete(project_dir, 'rf')
  for _, folder in pairs(TREE_FOLDER) do vim.fn.mkdir(project_dir .. '/' .. folder, 'p') end
  for _, entry in ipairs(entries) do
    if entry.link then
      local symlink = project_dir .. '/' .. entry.link
      vim.fn.mkdir(vim.fs.dirname(symlink), 'p')
      assert(vim.uv.fs_symlink(entry.file, symlink), 'navigator: cannot link ' .. symlink)
    end
  end
end

local function getPriority(module)
  if MODULE_PRIORITY[module] then return MODULE_PRIORITY[module] end
  for i, prefix in ipairs(FRAMEWORK_PREFIXES) do
    if module:match('^' .. prefix .. '_') then return i + vim.tbl_count(MODULE_PRIORITY) end
  end
  return #FRAMEWORK_PREFIXES + vim.tbl_count(MODULE_PRIORITY) + 1
end

local function getPickerItems(entries)
  local items = {}
  for _, entry in ipairs(entries) do
    items[#items + 1] = {
      text = entry.module .. '/' .. entry.display,
      file = entry.file,
      module = entry.module,
      display = entry.display,
    }
  end
  table.sort(items, function(a, b)
    local pa, pb = getPriority(a.module), getPriority(b.module)
    if pa ~= pb then return pa < pb end
    if a.module ~= b.module then return a.module < b.module end
    return a.display < b.display
  end)
  for i, item in ipairs(items) do
    item.idx = i
    item.score = i
  end
  return items
end

function M.files()
  local Snacks = require('snacks')
  if get_project() == nil then
    Snacks.picker.files()
  else
    Snacks.picker({
      items = getPickerItems(getEntries()),
      source = 'project_files',
      format = function(item)
        return {
          { item.module .. '/', 'DiagnosticInfo' },
          { item.display, 'Normal' },
        }
      end,
      actions = {
        confirm = function(picker, item)
          picker:close()
          vim.schedule(function()
            require('lsp.header-source').closeNonTerminalOthers()
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
end

-- The explorer-tree path of a real file, or nil when the file is not in
-- the tree.
local function getLink(entries, real_file)
  for _, entry in ipairs(entries) do
    if entry.file == real_file and entry.link then return get_project_dir() .. '/' .. entry.link end
  end
  return nil
end

local function showExplorer(project_dir, symlink_path)
  local Tree = require('snacks.explorer.tree')
  Tree:refresh(project_dir)
  if symlink_path ~= nil then
    Tree:open(symlink_path)
  end

  -- Persistent split sync while explorer is open: fires on every file navigation,
  -- cleared when the explorer closes.
  local explorerSyncGroup = vim.api.nvim_create_augroup('explorer_split_sync', { clear = true })
  local explorerSyncPrevious = vim.fn.expand('%:p')
  vim.api.nvim_create_autocmd('BufEnter', {
    group = explorerSyncGroup,
    callback = function()
      local cur = vim.fn.expand('%:p')
      if cur ~= explorerSyncPrevious and cur ~= '' then
        explorerSyncPrevious = cur
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

-- The explorer walks the symlink tree, which is built from the compile
-- database — nothing to show before the first build.
function M.open_explorer()
  if M.find_compile_db() == nil then
    vim.notify('No compile_commands.json - build first', vim.log.levels.WARN)
  else
    local entries = getEntries()
    if is_symlink_tree_stale() then generate_symlink_tree(entries) end
    showExplorer(get_project_dir(), getLink(entries, vim.fn.expand('%:p')))
  end
end

function M.regenerate()
  if M.find_compile_db() == nil then
    vim.notify('Failed to regenerate - no compile_commands.json', vim.log.levels.ERROR)
  else
    generate_symlink_tree(getEntries())
    require('core.project').parse(require('core.project').getRoot())
    vim.notify('Regenerated project tree + project state', vim.log.levels.INFO)
  end
end

-- The directories grep/replace cover: one per navigator tree (rg recurses
-- into each, so subdirs are never listed separately). nil outside a
-- project, so the pickers fall back to cwd.
local function get_dirs()
  if get_project() == nil then return nil end
  local dirs = vim.tbl_map(function(tree) return tree.dir end, getTrees())
  return #dirs > 0 and dirs or nil
end

local function getGrepArgs()
  return isGrepFixed and GREP_ARGS_FIXED or GREP_ARGS
end

local function getFixedSuffix()
  return isGrepFixed and ' [-F]' or ''
end

function M.grep(seed_search)
  local Snacks = require('snacks')
  local dirs = get_dirs()

  local function toggle_fixed(picker)
    local cur = picker.input.filter.search
    picker:close()
    isGrepFixed = not isGrepFixed
    vim.schedule(function() M.grep(cur) end)
  end

  local opts = {
    title   = 'Grep' .. getFixedSuffix(),
    actions = { toggle_fixed = toggle_fixed },
    win = {
      input = { keys = { ['<C-f>'] = { 'toggle_fixed', mode = { 'i', 'n' } } } },
      list  = { keys = { ['<C-f>'] = 'toggle_fixed' } },
    },
    args = getGrepArgs(),
  }
  if seed_search ~= nil then opts.search = seed_search end
  if dirs ~= nil       then opts.dirs   = dirs          end
  require('core.actions').splitSyncOnce()
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
    isGrepFixed = not isGrepFixed
    vim.schedule(function() M.replace_grep(cur) end)
  end

  local picker_opts = {
    title   = 'Grep (then Replace)' .. getFixedSuffix(),
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
    args = getGrepArgs(),
  }

  if seed_search ~= nil then picker_opts.search = seed_search end
  if dirs ~= nil         then picker_opts.dirs   = dirs        end
  Snacks.picker.grep(picker_opts)
end

-- Applies the replacement to every selected grep hit, one substitute per
-- hit line, saving each touched buffer.
local function applyReplacement(search, replacement, selected)
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

function M.replace(search)
  local Snacks = require('snacks')
  local dirs = get_dirs()
  local function apply(picker)
    local search      = picker.input.filter.search
    local replacement = vim.trim(picker.input.win:text())
    -- Explicit Tab-selection takes priority; fall back to all visible items.
    local selected = picker:selected()
    if #selected == 0 then selected = picker:items() end
    picker:close()
    if #selected == 0 then
      vim.notify('Nothing to replace', vim.log.levels.WARN)
    else
      applyReplacement(search, replacement, selected)
    end
  end

  local function toggle_fixed(picker)
    local cur = picker.input.filter.search
    picker:close()
    isGrepFixed = not isGrepFixed
    vim.schedule(function() M.replace(cur) end)
  end

  local picker_opts = {
    title  = 'Replace' .. getFixedSuffix(),
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
    args = getGrepArgs(),
  }

  if dirs ~= nil then picker_opts.dirs = dirs end
  Snacks.picker.grep(picker_opts)
end

return M
