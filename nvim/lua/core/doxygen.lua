-- core/doxygen.lua
-- Builds JUCE (HTML+XML+tagfile), library (HTML+XML), and project (XML only) doxygen docs.
-- Detects JAM vs KANJUT from project CMakeLists.txt.
-- Ensures project/doxygen/Doxyfile symlink exists before building.
--
-- leader bd  → build_clean  (always rebuild all)
-- leader bb  → build_incremental (rebuild only stale)
local M = {}

local is_windows = vim.fn.has('win32') == 1

local SCRIPT = vim.fn.stdpath('config') .. (is_windows and '\\scripts\\build-doxygen.sh' or '/scripts/build-doxygen.sh')

-- Fixed machine paths for JUCE (upstream of every JAM/KANJUT project).
-- Source: upstream clone. Output: nav-target dir referenced by CAROL.md.
local JUCE_DOXY    = '/Users/jreng/Documents/Poems/JUCE/docs/doxygen'
local JUCE_MODULES = '/Users/jreng/Documents/Poems/JUCE/modules'
local JUCE_OUT     = '/Users/jreng/Documents/Poems/JUCE-docs/doxygen'

local function get_project_root()
  local markers = vim.fs.find('CMakeLists.txt', {
    upward = true,
    path   = vim.fn.getcwd(),
    limit  = 1,
  })
  return #markers > 0 and vim.fn.fnamemodify(markers[1], ':h') or vim.fn.getcwd()
end

-- Returns absolute path to the library doxygen/ dir, or nil if undetected.
-- Three independent frameworks, three peer checks:
--   JAM     → marker JAM_ROOT                → ../jam/doxygen
--   CIUM    → ../___cium___/doxygen/Doxyfile → ../___cium___/doxygen
--   KANJUT  → marker FRAMEWORK_MODULES_PATH  → ../___lib___/doxygen
-- CIUM is detected by directory existence — no consumer project exists in
-- the monorepo to read a unique CMake marker from.
local function detect_lib_doxy(root)
  local cmake = root .. '/CMakeLists.txt'
  local f = io.open(cmake, 'r')
  if not f then return nil end
  local content = f:read('*a')
  f:close()

  if content:find('JAM_ROOT') then
    return vim.fn.fnamemodify(root .. '/../jam/doxygen', ':p'):gsub('/$', '')
  end
  if vim.loop.fs_stat(root .. '/../___cium___/doxygen/Doxyfile') then
    return vim.fn.fnamemodify(root .. '/../___cium___/doxygen', ':p'):gsub('/$', '')
  end
  if content:find('FRAMEWORK_MODULES_PATH') then
    return vim.fn.fnamemodify(root .. '/../___lib___/doxygen', ':p'):gsub('/$', '')
  end
  return nil
end

-- Ensures project/doxygen/ exists and Doxyfile symlink points to lib Doxyfile.project.
-- Returns project doxygen dir path, or nil on failure.
local function ensure_project_symlink(root, lib_doxy)
  local proj_doxy = root .. '/doxygen'
  vim.fn.mkdir(proj_doxy, 'p')

  local symlink  = proj_doxy .. '/Doxyfile'
  local target   = lib_doxy .. '/Doxyfile.project'

  if not vim.loop.fs_stat(target) then
    vim.notify('[doxygen] Missing template: ' .. target, vim.log.levels.WARN)
    return nil
  end

  local existing = vim.loop.fs_lstat(symlink)
  if existing then
    -- Already exists (symlink or file) — leave it alone
    return proj_doxy
  end

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

local function run_in_terminal(juce_doxy, juce_out, lib_doxy, proj_doxy)
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
    and { 'bash', SCRIPT, juce_doxy or '', juce_out or '', lib_doxy or '', proj_doxy or '' }
    or  { SCRIPT, juce_doxy or '', juce_out or '', lib_doxy or '', proj_doxy or '' }

  local function close_if_clean(code)
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
  local lib_doxy = detect_lib_doxy(root)
  if not lib_doxy then
    vim.notify('[doxygen] Cannot detect framework (no JAM_ROOT or FRAMEWORK_MODULES_PATH)', vim.log.levels.WARN)
    return
  end
  local proj_doxy = ensure_project_symlink(root, lib_doxy)
  run_in_terminal(JUCE_DOXY, JUCE_OUT, lib_doxy, proj_doxy)
end

-- Rebuild only what is stale. Called after successful binary build.
function M.build_incremental(root)
  root = root or get_project_root()
  local lib_doxy = detect_lib_doxy(root)
  if not lib_doxy then return end

  local proj_doxy = ensure_project_symlink(root, lib_doxy)

  local lib_root   = vim.fn.fnamemodify(lib_doxy, ':h')
  local lib_stale  = is_stale(lib_root,  lib_doxy  .. '/xml/index.xml')
  local proj_stale = proj_doxy and is_stale(root .. '/Source', proj_doxy .. '/xml/index.xml')
  local juce_stale = is_stale(JUCE_MODULES, JUCE_OUT .. '/xml/index.xml')

  if not lib_stale and not proj_stale and not juce_stale then return end

  run_in_terminal(
    juce_stale and JUCE_DOXY or '',
    juce_stale and JUCE_OUT  or '',
    lib_stale   and lib_doxy  or '',
    proj_stale  and proj_doxy or nil
  )
end

return M
