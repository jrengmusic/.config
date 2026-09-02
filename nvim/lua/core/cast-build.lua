-- core/cast-build.lua
-- Build job: the project builds itself entirely through the `cast` CLI
-- (~/Documents/Poems/dev/cast). What to launch afterwards is the project
-- state's selection (core/project.lua, dap/launch.lua); this module only
-- runs the toolchain and hands control back on success.
--
-- The framework's own manifest (<user-module root>/cast/CAST.md) is
-- regenerated first, unconditionally -- a project build never runs against
-- stale generated framework headers. It carries no ## toolchain table of
-- its own, so this run is codegen only (no configure/build step fires for
-- it). A framework without a cast manifest has nothing to regenerate.
local M = {}

local is_windows = vim.fn.has('win32') == 1

local CAST_BINARY = is_windows and 'cast.exe' or 'cast'
local TOOLCHAIN_MANIFEST = require('core.project.cast').TOOLCHAIN_MANIFEST

-- Keymap scheme -> ## toolchain argument (a configuration key in the
-- project state). Debug builds fast and unsigned; Release builds optimized
-- and unsigned (no-sign) for local iteration. The fully signed/notarized/
-- installed default flow (bare `cast cast/CAST.md`, no toolchain argument)
-- is a deliberate manual step, never bound to a keymap.
M.TOOLCHAIN_ARGUMENT = {
  Debug = 'debug',
  Release = 'no-sign',
}

function M.build(project, argument, onSuccess)
  local build = require('core.build')
  local frameworkManifest = project.dependencies.user.root .. '/' .. TOOLCHAIN_MANIFEST

  local function buildProject()
    build.runBuildJob({ CAST_BINARY, TOOLCHAIN_MANIFEST, '--' .. argument }, onSuccess)
  end

  if vim.fn.filereadable(frameworkManifest) == 1 then
    build.runBuildJob({ CAST_BINARY, frameworkManifest }, buildProject)
  else
    buildProject()
  end
end

return M
