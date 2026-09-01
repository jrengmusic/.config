-- core/cast-build.lua
-- Build orchestration for cast-managed projects: any project whose root
-- carries cast/CAST.md builds itself entirely through the `cast` CLI
-- (~/Documents/Poems/dev/cast) -- no build-debug.{sh,bat}, no DAP/DAW
-- launch, since cast projects generate their own self-sufficient
-- CMakeLists.txt and produce no Standalone/plugin target to attach a
-- debugger to.
--
-- The framework's own manifest (../jam/cast/CAST.md) is regenerated first,
-- unconditionally -- a project build never runs against stale generated
-- framework headers. It carries no ## toolchain table of its own, so this
-- run is codegen only (no configure/build step fires for it).
local M = {}

local is_windows = vim.fn.has('win32') == 1

local CAST_BINARY = is_windows and 'cast.exe' or 'cast'
local FRAMEWORK_MANIFEST = '../jam/cast/CAST.md'
local PROJECT_MANIFEST = 'cast/CAST.md'

-- Debug builds fast and unsigned; Release builds optimized and unsigned
-- (--no-sign) for local iteration. The fully signed/notarized/installed
-- default flow (bare `cast cast/CAST.md`, no toolchain argument) is a
-- deliberate manual step, never bound to a keymap.
local TOOLCHAIN_ARGUMENT = {
  Debug = 'debug',
  Release = 'no-sign',
}

function M.isCastManaged(root)
  return vim.fn.filereadable(root .. '/' .. PROJECT_MANIFEST) == 1
end

function M.build(scheme)
  local build = require('core.build')
  local toolchainArgument = TOOLCHAIN_ARGUMENT[scheme]

  local function buildProject()
    build.runBuildJob(
      { CAST_BINARY, PROJECT_MANIFEST, '--' .. toolchainArgument },
      function() vim.notify('Built!', vim.log.levels.INFO, { timeout = 1500 }) end
    )
  end

  build.runBuildJob({ CAST_BINARY, FRAMEWORK_MANIFEST }, buildProject)
end

return M
