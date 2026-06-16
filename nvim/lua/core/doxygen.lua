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

local SCRIPT        = vim.fn.stdpath('config') .. (is_windows and '\\scripts\\build-doxygen.sh' or '/scripts/build-doxygen.sh')
local TEMPLATE_LIB  = vim.fn.stdpath('config') .. (is_windows and '\\doxygen\\Doxyfile.lib'  or '/doxygen/Doxyfile.lib')
local TEMPLATE_JUCE = vim.fn.stdpath('config') .. (is_windows and '\\doxygen\\Doxyfile.juce' or '/doxygen/Doxyfile.juce')

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

-- Returns lib root dir (e.g. .../jam, .../ ___lib___), or nil if undetected.
-- Three independent frameworks, three peer checks:
--   JAM     → marker JAM_ROOT                → ../jam
--   CIUM    → ../___cium___/doxygen/Doxyfile → ../___cium___
--   KANJUT  → marker FRAMEWORK_MODULES_PATH  → ../___lib___
local function detect_lib_root(root)
  local cmake = root .. '/CMakeLists.txt'
  local f = io.open(cmake, 'r')
  if not f then return nil end
  local content = f:read('*a')
  f:close()

  if content:find('JAM_ROOT') then
    return vim.fn.fnamemodify(root .. '/../jam', ':p'):gsub('/$', '')
  end
  if vim.loop.fs_stat(root .. '/../___cium___/doxygen/Doxyfile') then
    return vim.fn.fnamemodify(root .. '/../___cium___', ':p'):gsub('/$', '')
  end
  if content:find('FRAMEWORK_MODULES_PATH') then
    return vim.fn.fnamemodify(root .. '/../___lib___', ':p'):gsub('/$', '')
  end
  return nil
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
-- TAGFILES path: relative from {lib}/docs/ — three levels up reaches Poems/ where JUCE/ lives.
local function make_lib_doxyfile(lib_root, name, brief)
  local tf = io.open(TEMPLATE_LIB, 'r')
  assert(tf, '[doxygen] Missing template: ' .. TEMPLATE_LIB)
  local content = tf:read('*a')
  tf:close()

  content = content:gsub('__JUCE_DOXYFILE__', JUCE_DOXYFILE)
  content = content:gsub('__PROJECT_NAME__',  name)
  content = content:gsub('__PROJECT_BRIEF__', brief)
  content = content:gsub('__INPUT__',         lib_root)
  content = content:gsub('__TAGFILES__',      '../../../JUCE/docs/tagfile.xml=../../../../JUCE/docs/html')
  content = content:gsub('__DOT_MAX_NODES__', '100')

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

-- Ensures project/doxygen/ exists and Doxyfile symlink points to lib's Doxyfile.project.
-- Returns project doxygen dir path, or nil on failure.
local function ensure_project_symlink(root, lib_root)
  local proj_doxy = root .. '/doxygen'
  vim.fn.mkdir(proj_doxy, 'p')

  local symlink = proj_doxy .. '/Doxyfile'
  local target  = lib_root .. '/doxygen/Doxyfile.project'

  if not vim.loop.fs_stat(target) then
    vim.notify('[doxygen] Missing template: ' .. target, vim.log.levels.WARN)
    return nil
  end

  local existing = vim.loop.fs_lstat(symlink)
  if existing then return proj_doxy end

  vim.loop.fs_symlink(target, symlink)
  return proj_doxy
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

local function run_in_terminal(juce_doxy_tmp, lib_doxy_tmp, lib_root, proj_doxy)
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
          lib_doxy_tmp  or '', lib_root  or '',
          proj_doxy     or '' }
    or  { SCRIPT,
          juce_doxy_tmp or '', JUCE_DOXY_DIR, JUCE_ROOT,
          lib_doxy_tmp  or '', lib_root  or '',
          proj_doxy     or '' }

  local function close_if_clean(code)
    if juce_doxy_tmp then vim.loop.fs_unlink(juce_doxy_tmp) end
    if lib_doxy_tmp  then vim.loop.fs_unlink(lib_doxy_tmp)  end

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
  local juce_tmp  = make_juce_doxyfile()
  local lib_tmp   = make_lib_doxyfile_for(lib_root)
  local proj_doxy = ensure_project_symlink(root, lib_root)
  run_in_terminal(juce_tmp, lib_tmp, lib_root, proj_doxy)
end

-- Rebuild only what is stale. Called after successful binary build.
function M.build_incremental(root)
  root = root or get_project_root()
  local lib_root = detect_lib_root(root)
  if not lib_root then return end

  local proj_doxy  = ensure_project_symlink(root, lib_root)
  local juce_stale = is_stale(JUCE_MODULES, JUCE_ROOT .. '/docs/xml/index.xml')
  local lib_stale  = is_stale(lib_root,     lib_root  .. '/docs/xml/index.xml')
  local proj_stale = proj_doxy and is_stale(root .. '/Source', root .. '/doxygen/xml/index.xml')

  if not juce_stale and not lib_stale and not proj_stale then return end

  local juce_tmp = juce_stale and make_juce_doxyfile()            or nil
  local lib_tmp  = lib_stale  and make_lib_doxyfile_for(lib_root) or nil

  run_in_terminal(
    juce_tmp,
    lib_tmp,
    lib_stale  and lib_root  or '',
    proj_stale and proj_doxy or nil
  )
end

return M
