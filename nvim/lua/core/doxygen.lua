-- core/doxygen.lua
-- Builds JUCE (HTML+XML+tagfile), library (HTML+XML), and project (XML only) doxygen docs.
-- Detects JAM vs KANJUT vs CIUM from project CMakeLists.txt.
-- All lib docs built from unified ~/.config/nvim/doxygen/Doxyfile.lib template.
-- Output: {lib}/docs/html/, {lib}/docs/xml/, {lib}/DOCS.html (root redirect)
--
-- leader bd  → build_clean  (always rebuild all)
-- leader bb  → build_incremental (rebuild only stale, post-binary-build hook)
local M = {}

local is_windows = vim.fn.has('win32') == 1

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

-- Fixed machine paths
local HOME          = vim.fn.expand('~'):gsub('\\', '/')
local JUCE_ROOT     = HOME .. '/Documents/Poems/JUCE'
local JUCE_MODULES  = JUCE_ROOT .. '/modules'
local JUCE_DOXY_DIR = JUCE_ROOT .. '/docs/doxygen'
local JUCE_DOXYFILE = JUCE_DOXY_DIR .. '/Doxyfile'

local function get_project_root()
  local markers = vim.fs.find('CMakeLists.txt', {
    upward = true,
    path   = vim.fn.getcwd(),
    limit  = 1,
  })
  return #markers > 0 and vim.fn.fnamemodify(markers[1], ':h') or vim.fn.getcwd()
end

-- Substitutes the two CMake variable forms seen across project CMakeLists.txt
-- (${CMAKE_CURRENT_SOURCE_DIR} and $ENV{HOME}) with their resolved values.
local function resolve_cmake_value(value, root)
  value = value:gsub('%$%{CMAKE_CURRENT_SOURCE_DIR%}', root)
  value = value:gsub('%$ENV%{HOME%}', HOME)
  return value
end

-- Returns lib root dir (e.g. .../jam, .../___lib___), or nil if undetected.
-- Three independent frameworks, three peer checks:
--   JAM     → marker JAM_ROOT                → parsed from set(JAM_ROOT "...")
--   CIUM    → ../___cium___/docs/Doxyfile    → ../___cium___
--   KANJUT  → marker FRAMEWORK_MODULES_PATH  → parsed from FRAMEWORK_PATH + FRAMEWORK_MODULES_PATH
-- Values are parsed rather than assumed at a fixed nesting depth — projects
-- nest at varying depths under dev/ and kuassa/ (e.g. dev/plugins/whelmed
-- sets JAM_ROOT two levels up, dev/end sets it one level up).
local function detect_lib_root(root)
  local cmake = root .. '/CMakeLists.txt'
  local f = io.open(cmake, 'r')
  if not f then return nil end
  local content = f:read('*a')
  f:close()

  local jam_root = content:match('set%(%s*JAM_ROOT%s+"([^"]+)"%s*%)')
  if jam_root then
    return vim.fn.fnamemodify(resolve_cmake_value(jam_root, root), ':p'):gsub('\\', '/'):gsub('/$', '')
  end
  if vim.loop.fs_stat(root .. '/../___cium___/docs/Doxyfile') then
    return vim.fn.fnamemodify(root .. '/../___cium___', ':p'):gsub('\\', '/'):gsub('/$', '')
  end
  local modules_path = content:match('set%(%s*FRAMEWORK_MODULES_PATH%s+"([^"]+)"%s*%)')
  if modules_path then
    local framework_path = content:match('set%(%s*FRAMEWORK_PATH%s+"([^"]+)"%s*%)') or '${CMAKE_CURRENT_SOURCE_DIR}/..'
    local combined = resolve_cmake_value(framework_path, root) .. '/' .. modules_path
    return vim.fn.fnamemodify(combined, ':p'):gsub('\\', '/'):gsub('/$', '')
  end
  return nil
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

-- Copies TEMPLATE_JUCE to a temp file as-is. Returns temp path.
-- JUCE runs from JUCE_DOXY_DIR so @INCLUDE = Doxyfile resolves correctly.
local function make_juce_doxyfile()
  local tf = io.open(TEMPLATE_JUCE, 'r')
  assert(tf, '[doxygen] Missing template: ' .. TEMPLATE_JUCE)
  local content = tf:read('*a')
  tf:close()
  local tmp = vim.fn.tempname()
  local out = io.open(tmp, 'w')
  assert(out, '[doxygen] Cannot write temp Doxyfile')
  out:write(content)
  out:close()
  return tmp
end

-- Reads TEMPLATE_LIB, substitutes __MARKERS__, writes to a temp file. Returns temp path.
-- TAGFILES path: relative from {lib}/docs/ (cwd) to JUCE_ROOT, computed via relpath().
-- HTML-side gets one extra '..': generated HTML pages live in {lib}/docs/html/, one level
-- deeper than cwd, so doxygen resolves that half relative to the html/ output dir.
local function make_lib_doxyfile(lib_root, name, brief)
  local tf = io.open(TEMPLATE_LIB, 'r')
  assert(tf, '[doxygen] Missing template: ' .. TEMPLATE_LIB)
  local content = tf:read('*a')
  tf:close()

  local juce_rel = relpath(lib_root .. '/docs', JUCE_ROOT)

  content = content:gsub('__JUCE_DOXYFILE__', JUCE_DOXYFILE)
  content = content:gsub('__PROJECT_NAME__',  name)
  content = content:gsub('__PROJECT_BRIEF__', brief)
  content = content:gsub('__INPUT__',         lib_root)
  content = content:gsub('__TAGFILES__',      juce_rel .. '/docs/tagfile.xml=../' .. juce_rel .. '/docs/html')
  content = content:gsub('__DOT_MAX_NODES__',    '100')
  content = content:gsub('__EXCLUDE_PATTERNS__', format_exclude_patterns())

  local tmp = vim.fn.tempname()
  local out = io.open(tmp, 'w')
  assert(out, '[doxygen] Cannot write temp Doxyfile')
  out:write(content)
  out:close()
  return tmp
end

-- Derives name/brief/tmp Doxyfile from lib root dirname.
local function make_lib_doxyfile_for(lib_root)
  local tail = vim.fn.fnamemodify(lib_root, ':t')
  if tail == 'jam'        then return make_lib_doxyfile(lib_root, 'JAM',    'JRENG Architectural Modules')         end
  if tail == '___lib___'  then return make_lib_doxyfile(lib_root, 'KANJUT', 'Kuassa Audio Plugin Framework v2.0') end
  if tail == '___cium___' then return make_lib_doxyfile(lib_root, 'CIUM',   'CIUM v1.0')                          end
  return make_lib_doxyfile(lib_root, tail, tail)
end

-- Reads TEMPLATE_PROJECT, substitutes __INPUT__ and __TAGFILES__, writes to a temp file. Returns temp path.
local function make_project_doxyfile(lib_root, root)
  local tf = io.open(TEMPLATE_PROJECT, 'r')
  assert(tf, '[doxygen] Missing template: ' .. TEMPLATE_PROJECT)
  local content = tf:read('*a')
  tf:close()

  local proj_docs = root .. '/docs'
  local lib_rel   = relpath(proj_docs, lib_root)
  local juce_rel  = relpath(proj_docs, JUCE_ROOT)
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
  local stat = vim.loop.fs_stat(dir)
  if not stat then return 0 end
  local newest = stat.mtime.sec
  local handle = vim.loop.fs_scandir(dir)
  while handle do
    local name, ftype = vim.loop.fs_scandir_next(handle)
    if not name then break end
    local path = dir .. '/' .. name
    if ftype == 'directory' then
      local sub = newest_mtime(path)
      if sub > newest then newest = sub end
    elseif ftype == 'file' and (name:match('%.h$') or name:match('%.cpp$') or name:match('%.mm$')) then
      local s = vim.loop.fs_stat(path)
      if s and s.mtime.sec > newest then newest = s.mtime.sec end
    end
  end
  return newest
end

local function is_stale(src_dir, xml_stamp)
  local stamp = vim.loop.fs_stat(xml_stamp)
  if not stamp then return true end
  return newest_mtime(src_dir) > stamp.mtime.sec
end

local function run_in_terminal(juce_doxy_tmp, lib_doxy_tmp, lib_root, proj_doxy_tmp, proj_dir)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == 'terminal' then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.cmd('botright 15split')
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(term_buf)
  local term_win = vim.api.nvim_get_current_win()

  local args = is_windows
    and { 'bash', SCRIPT,
          juce_doxy_tmp or '', JUCE_DOXY_DIR, JUCE_ROOT,
          lib_doxy_tmp  or '', lib_root      or '',
          proj_doxy_tmp or '', proj_dir      or '' }
    or  { SCRIPT,
          juce_doxy_tmp or '', JUCE_DOXY_DIR, JUCE_ROOT,
          lib_doxy_tmp  or '', lib_root      or '',
          proj_doxy_tmp or '', proj_dir      or '' }

  local function close_if_clean(code)
    if juce_doxy_tmp then vim.loop.fs_unlink(juce_doxy_tmp) end
    if lib_doxy_tmp  then vim.loop.fs_unlink(lib_doxy_tmp)  end
    if proj_doxy_tmp then vim.loop.fs_unlink(proj_doxy_tmp) end

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
    vim.fn.jobstart(args, { term = true, on_exit = function(_, code)
      vim.schedule(function()
        vim.cmd('stopinsert')
        close_if_clean(code)
      end)
    end })
  else
    vim.fn.termopen(args)
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
  root = root or get_project_root()
  local lib_root = detect_lib_root(root)
  if not lib_root then
    vim.notify('[doxygen] Cannot detect framework (no JAM_ROOT or FRAMEWORK_MODULES_PATH)', vim.log.levels.WARN)
    return
  end
  local juce_tmp = make_juce_doxyfile()
  local lib_tmp  = make_lib_doxyfile_for(lib_root)
  local proj_tmp = make_project_doxyfile(lib_root, root)
  local proj_dir = ensure_project_docs_dir(root)
  run_in_terminal(juce_tmp, lib_tmp, lib_root, proj_tmp, proj_dir)
end

-- Rebuild only what is stale. Called after successful binary build.
function M.build_incremental(root)
  root = root or get_project_root()
  local lib_root = detect_lib_root(root)
  if not lib_root then return end

  local juce_stale = is_stale(JUCE_MODULES, JUCE_ROOT .. '/docs/xml/index.xml')
  local lib_stale  = is_stale(lib_root,     lib_root  .. '/docs/xml/index.xml')
  local proj_stale = is_stale(root .. '/Source', root .. '/docs/xml/index.xml')

  if not juce_stale and not lib_stale and not proj_stale then return end

  local juce_tmp = juce_stale and make_juce_doxyfile()            or nil
  local lib_tmp  = lib_stale  and make_lib_doxyfile_for(lib_root) or nil
  local proj_tmp = proj_stale and make_project_doxyfile(lib_root, root) or nil
  local proj_dir = proj_stale and ensure_project_docs_dir(root)         or nil

  run_in_terminal(
    juce_tmp,
    lib_tmp,
    lib_stale  and lib_root  or '',
    proj_tmp,
    proj_dir
  )
end

return M
