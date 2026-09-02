-- core/doxygen.lua
-- Builds JUCE (HTML+XML+tagfile), library (HTML+XML), and project (XML only) doxygen docs.
-- JUCE root and framework root come from the project state (core/project.lua).
-- All lib docs built from unified ~/.config/nvim/doxygen/Doxyfile.lib template.
-- Output: {lib}/docs/html/, {lib}/docs/xml/, {lib}/DOCS.html (root redirect)
--
-- leader bd  → build_clean  (always rebuild all, manual)
-- build_incremental (rebuild only stale) is triggered by the debounced
-- source-tree watcher in core/autocommands.lua, not by any keymap.
local M = {}

local is_windows = vim.fn.has('win32') == 1

local DOT_MAX_NODES = 100
local TERMINAL_HEIGHT = 15

-- Half of logical cores, floor, minimum 1 — identical formula to the clangd
-- `-j` cap (nvim/lua/lsp/clangd.lua), same vim.uv API on both platforms, so
-- doxygen's dot-graph rendering never saturates every core the way clangd's
-- unthrottled background-index did.
local function dot_num_threads()
  return math.max(1, math.floor(vim.uv.available_parallelism() / 2))
end

-- Only one doxygen job may run at a time — a second trigger (e.g. two builds
-- in quick succession) stops the previous job rather than letting both
-- compete for CPU. jobstop on an already-exited id is a documented no-op.
local active_job_id = nil
local function stop_active_job()
  if active_job_id then
    vim.fn.jobstop(active_job_id)
    active_job_id = nil
  end
end
-- Published on M so autocommands.lua's VimLeavePre can stop the doxygen job
-- still running (if any) when nvim quits.
M.stop_active_job = stop_active_job

local SCRIPT            = vim.fn.stdpath('config') .. (is_windows and '\\scripts\\build-doxygen.sh'     or '/scripts/build-doxygen.sh')
local TEMPLATE_LIB      = vim.fn.stdpath('config') .. (is_windows and '\\doxygen\\Doxyfile.lib'         or '/doxygen/Doxyfile.lib')
local TEMPLATE_JUCE     = vim.fn.stdpath('config') .. (is_windows and '\\doxygen\\Doxyfile.juce'        or '/doxygen/Doxyfile.juce')
local TEMPLATE_PROJECT  = vim.fn.stdpath('config') .. (is_windows and '\\doxygen\\Doxyfile.project'     or '/doxygen/Doxyfile.project')

-- Patterns excluded from all lib doxygen builds.
-- COMMON_LIB_EXCLUDES : build artifacts and meta dirs
-- VENDOR_DIR_NAMES    : known third-party embedded dirs (any lib, any depth)
local COMMON_LIB_EXCLUDES = {
  '*/Builds/*',
  '*/JuceLibraryCode/*',
  '*/.git/*',
  '*/doxygen/*',
  '*/docs/*',
  '*/.DS_Store',
  '*/codebase-for-dummies/*',
  '*/automation/*',
  '*/cast/template/*',
}

local VENDOR_DIR_NAMES = {
  '___sdk___',
  '___SDK___',
  'freetype',
  'vma',
  'glm',
  'moltenVK',
  'vulkan',
  'spv',
  'clap',
}

-- Formats combined exclude list as a Doxygen multiline value string.
-- Caller substitutes the result into __EXCLUDE_PATTERNS__.
local EXCLUDE_PATTERNS_PAD = string.rep(' ', 25)
local function format_exclude_patterns()
  local all = {}
  for _, p in ipairs(COMMON_LIB_EXCLUDES) do all[#all + 1] = p end
  for _, n in ipairs(VENDOR_DIR_NAMES)    do all[#all + 1] = '*/' .. n .. '/*' end
  return table.concat(all, ' \\\n' .. EXCLUDE_PATTERNS_PAD)
end

-- Normalizes a path to forward slashes, stripping any trailing slash.
-- vim.fn.fnamemodify(..., ':p'/':h') returns native-separator paths, which on
-- Windows means backslashes — relpath() below is forward-slash-only, so every
-- absolute path entering it must be normalized through this single point.
local function normalize_path(path)
  return (path:gsub('\\', '/'):gsub('/$', ''))
end

-- Registry lookup by the registry's own key (core/project.getRoot's
-- normalisation), never this module's forward-slash normalizer.
local function get_project(root)
  local project = require('core.project')
  return project.getOrCreate(root and vim.fs.normalize(root) or project.getRoot())
end

-- JUCE doc locations from the project state's JUCE root. JUCE runs from
-- doxy_dir so its @INCLUDE = Doxyfile resolves.
local function get_juce(project)
  local juce_root = normalize_path(project.dependencies.juce.root)
  return {
    root     = juce_root,
    modules  = juce_root .. '/modules',
    doxy_dir = juce_root .. '/docs/doxygen',
    doxyfile = juce_root .. '/docs/doxygen/Doxyfile',
  }
end

-- The project root the docs are built for: the project state's, or cwd
-- when nvim is not in a project (nothing to build then).
function M.get_project_root()
  local project = get_project()
  return project and normalize_path(project.manifest.root) or normalize_path(vim.fn.getcwd())
end

-- The framework root the project builds against (dependencies.user.root),
-- or nil outside a project.
function M.detect_lib_root(root)
  local project = get_project(root)
  return project and normalize_path(project.dependencies.user.root) or nil
end

-- Returns the relative path from absolute dir `from_dir` to absolute dir `to_dir`.
-- Walks common leading components, then emits '..' for the remainder of from_dir
-- followed by the remainder of to_dir. Depth-agnostic — no assumed nesting level.
local function relpath(from_dir, to_dir)
  local from_parts = vim.split(from_dir, '/', { trimempty = true })
  local to_parts   = vim.split(to_dir,   '/', { trimempty = true })
  local i = 1
  while from_parts[i] and to_parts[i] and from_parts[i] == to_parts[i] do
    i = i + 1
  end
  local parts = {}
  for _ = i, #from_parts do parts[#parts + 1] = '..' end
  for j = i, #to_parts   do parts[#parts + 1] = to_parts[j] end
  return table.concat(parts, '/')
end

-- Reads TEMPLATE_JUCE, substitutes __DOT_NUM_THREADS__, writes to a temp file.
-- Returns temp path. JUCE runs from juce.doxy_dir so @INCLUDE = Doxyfile
-- resolves correctly.
local function make_juce_doxyfile()
  local tf = io.open(TEMPLATE_JUCE, 'r')
  assert(tf, '[doxygen] Missing template: ' .. TEMPLATE_JUCE)
  local content = tf:read('*a')
  tf:close()
  content = content:gsub('__DOT_NUM_THREADS__', tostring(dot_num_threads()))
  local tmp = vim.fn.tempname()
  local out = io.open(tmp, 'w')
  assert(out, '[doxygen] Cannot write temp Doxyfile')
  out:write(content)
  out:close()
  return tmp
end

-- Reads TEMPLATE_LIB, substitutes __MARKERS__, writes to a temp file. Returns temp path.
-- TAGFILES path: relative from {lib}/docs/ (cwd) to the JUCE root, computed via relpath().
-- HTML-side gets one extra '..': generated HTML pages live in {lib}/docs/html/, one level
-- deeper than cwd, so doxygen resolves that half relative to the html/ output dir.
local function make_lib_doxyfile(juce, lib_root, name, brief)
  local tf = io.open(TEMPLATE_LIB, 'r')
  assert(tf, '[doxygen] Missing template: ' .. TEMPLATE_LIB)
  local content = tf:read('*a')
  tf:close()

  local juce_rel = relpath(lib_root .. '/docs', juce.root)

  content = content:gsub('__JUCE_DOXYFILE__', juce.doxyfile)
  content = content:gsub('__PROJECT_NAME__',  name)
  content = content:gsub('__PROJECT_BRIEF__', brief)
  content = content:gsub('__INPUT__',         lib_root)
  content = content:gsub('__TAGFILES__',      juce_rel .. '/docs/tagfile.xml=../' .. juce_rel .. '/docs/html')
  content = content:gsub('__DOT_MAX_NODES__',    tostring(DOT_MAX_NODES))
  content = content:gsub('__DOT_NUM_THREADS__',  tostring(dot_num_threads()))
  content = content:gsub('__EXCLUDE_PATTERNS__', format_exclude_patterns())

  local tmp = vim.fn.tempname()
  local out = io.open(tmp, 'w')
  assert(out, '[doxygen] Cannot write temp Doxyfile')
  out:write(content)
  out:close()
  return tmp
end

-- Derives name/brief/tmp Doxyfile from lib root dirname.
local LIB_IDENTITY = {
  jam        = { name = 'JAM',    brief = 'JRENG Architectural Modules' },
  ___lib___  = { name = 'KANJUT', brief = 'Kuassa Audio Plugin Framework v2.0' },
  ___cium___ = { name = 'CIUM',   brief = 'CIUM v1.0' },
}

local function make_lib_doxyfile_for(juce, lib_root)
  local tail = vim.fn.fnamemodify(lib_root, ':t')
  local identity = LIB_IDENTITY[tail] or { name = tail, brief = tail }
  return make_lib_doxyfile(juce, lib_root, identity.name, identity.brief)
end

-- Reads TEMPLATE_PROJECT, substitutes __INPUT__ and __TAGFILES__, writes to a temp file. Returns temp path.
local function make_project_doxyfile(juce, lib_root, root)
  local tf = io.open(TEMPLATE_PROJECT, 'r')
  assert(tf, '[doxygen] Missing template: ' .. TEMPLATE_PROJECT)
  local content = tf:read('*a')
  tf:close()

  local proj_docs = root .. '/docs'
  local lib_rel   = relpath(proj_docs, lib_root)
  local juce_rel  = relpath(proj_docs, juce.root)
  local lib_tag   = lib_rel  .. '/docs/tagfile.xml=' .. lib_rel  .. '/docs/html'
  local juce_tag  = juce_rel .. '/docs/tagfile.xml=' .. juce_rel .. '/docs/html'

  content = content:gsub('__INPUT__',    root .. '/Source')
  content = content:gsub('__TAGFILES__', lib_tag .. ' \\\n                         ' .. juce_tag)

  local tmp = vim.fn.tempname()
  local out = io.open(tmp, 'w')
  assert(out, '[doxygen] Cannot write temp project Doxyfile')
  out:write(content)
  out:close()
  return tmp
end

-- Ensures project/docs/ exists. Returns project docs dir path.
local function ensure_project_docs_dir(root)
  local proj_docs = root .. '/docs'
  vim.fn.mkdir(proj_docs, 'p')
  return proj_docs
end

local function newest_mtime(dir)
  local stat = vim.uv.fs_stat(dir)
  if not stat then return 0 end
  local newest = stat.mtime.sec
  local handle = vim.uv.fs_scandir(dir)
  while handle do
    local name, ftype = vim.uv.fs_scandir_next(handle)
    if not name then break end
    local path = dir .. '/' .. name
    if ftype == 'directory' then
      local sub = newest_mtime(path)
      if sub > newest then newest = sub end
    elseif ftype == 'file' and (name:match('%.h$') or name:match('%.cpp$') or name:match('%.mm$')) then
      local s = vim.uv.fs_stat(path)
      if s and s.mtime.sec > newest then newest = s.mtime.sec end
    end
  end
  return newest
end

local function is_stale(src_dir, xml_stamp)
  local stamp = vim.uv.fs_stat(xml_stamp)
  if not stamp then return true end
  return newest_mtime(src_dir) > stamp.mtime.sec
end

local function run_in_terminal(juce, juce_doxy_tmp, lib_doxy_tmp, lib_root, proj_doxy_tmp, proj_dir)
  stop_active_job()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == 'terminal' then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.cmd('botright ' .. TERMINAL_HEIGHT .. 'split')
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(term_buf)
  local term_win = vim.api.nvim_get_current_win()

  local args = is_windows
    and { 'bash', SCRIPT,
          juce_doxy_tmp or '', juce.doxy_dir, juce.root,
          lib_doxy_tmp  or '', lib_root      or '',
          proj_doxy_tmp or '', proj_dir      or '' }
    or  { SCRIPT,
          juce_doxy_tmp or '', juce.doxy_dir, juce.root,
          lib_doxy_tmp  or '', lib_root      or '',
          proj_doxy_tmp or '', proj_dir      or '' }

  local function close_if_clean(code)
    if juce_doxy_tmp then vim.uv.fs_unlink(juce_doxy_tmp) end
    if lib_doxy_tmp  then vim.uv.fs_unlink(lib_doxy_tmp)  end
    if proj_doxy_tmp then vim.uv.fs_unlink(proj_doxy_tmp) end

    if code ~= 0 then
      vim.notify('[doxygen] Failed (exit ' .. code .. ')', vim.log.levels.ERROR)
      return
    end
    local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
    local has_warning = false
    for _, line in ipairs(lines) do
      if line:find('[Ww]arning') then
        has_warning = true
        break
      end
    end
    if has_warning then
      vim.notify('[doxygen] Done (warnings)', vim.log.levels.WARN)
    else
      if vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_close(term_win, true)
      end
      vim.notify('[doxygen] Done', vim.log.levels.INFO)
    end
  end

  if is_windows then
    active_job_id = vim.fn.jobstart(args, { term = true, on_exit = function(_, code)
      vim.schedule(function()
        vim.cmd('stopinsert')
        close_if_clean(code)
      end)
    end })
  else
    active_job_id = vim.fn.termopen(args)
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = term_buf,
      once   = true,
      callback = function()
        local code = vim.v.event.status
        vim.schedule(function()
          vim.cmd('stopinsert')
          close_if_clean(code)
        end)
      end,
    })
  end

  vim.cmd('startinsert')
end

-- Force clean rebuild of JUCE + library (HTML+XML) + project (XML).
function M.build(root)
  local project = get_project(root)
  if project then
    root = normalize_path(project.manifest.root)
    local lib_root = M.detect_lib_root(root)
    local juce     = get_juce(project)
    local juce_tmp = make_juce_doxyfile()
    local lib_tmp  = make_lib_doxyfile_for(juce, lib_root)
    local proj_tmp = make_project_doxyfile(juce, lib_root, root)
    local proj_dir = ensure_project_docs_dir(root)
    run_in_terminal(juce, juce_tmp, lib_tmp, lib_root, proj_tmp, proj_dir)
  else
    vim.notify('[doxygen] No project state here: a project needs project-info.md and cast/CAST.md', vim.log.levels.WARN)
  end
end

-- Returns the three source trees build_incremental checks for staleness
-- (JUCE modules, framework lib, project Source), or nil outside a project.
-- Lets callers (e.g. a file watcher) watch exactly what build_incremental
-- reads, without duplicating its knowledge of juce.modules/lib_root/Source.
function M.get_watch_dirs(root)
  local project = get_project(root)
  if not project then return nil end
  return { get_juce(project).modules, M.detect_lib_root(root), normalize_path(project.manifest.root) .. '/Source' }
end

-- Rebuild only what is stale. Called by the doxygen source-tree watcher
-- (core/autocommands.lua), debounced — not tied to binary build completion.
local function build_stale(project)
  local root = normalize_path(project.manifest.root)
  local lib_root = M.detect_lib_root(root)
  local juce = get_juce(project)
  local juce_stale = is_stale(juce.modules, juce.root .. '/docs/xml/index.xml')
  local lib_stale  = is_stale(lib_root,     lib_root  .. '/docs/xml/index.xml')
  local proj_stale = is_stale(root .. '/Source', root .. '/docs/xml/index.xml')

  if juce_stale or lib_stale or proj_stale then
    run_in_terminal(
      juce,
      juce_stale and make_juce_doxyfile() or nil,
      lib_stale  and make_lib_doxyfile_for(juce, lib_root) or nil,
      lib_stale  and lib_root or '',
      proj_stale and make_project_doxyfile(juce, lib_root, root) or nil,
      proj_stale and ensure_project_docs_dir(root) or nil
    )
  end
end

function M.build_incremental(root)
  local project = get_project(root)
  if project then build_stale(project) end
end

return M
