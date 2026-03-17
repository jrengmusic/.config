-- Plugin spec helper
local depsGroups = require('plugins-deps')

local function plug(p)
  local spec = { p.repo }

  local moduleSpec = {}
  if p.module then
    local ok, m = pcall(require, p.module)
    assert(ok, ('invalid module(): %s'):format(p.module))
    moduleSpec = m
  end

  -- merge module spec with overrides
  for k, v in pairs(moduleSpec) do
    if k ~= 'setup' then
      spec[k] = v
    end
  end

  -- resolve dependency groups
  if spec.deps then
    spec.dependencies = depsGroups[spec.deps] or spec.deps
    spec.deps = nil
  end

  -- wrap setup into config
  if moduleSpec.setup then
    spec.config = function()
      moduleSpec.setup()
    end
  end

  return spec
end

return plug
