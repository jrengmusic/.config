-- core/project/cast.lua
-- CAST locator: builds the project AST for a cast-managed project from its
-- sources -- project-info.md (the manifest) and each configuration's
-- compile_commands.json. Every value written into the AST traces to one
-- table row or one compile-database entry; nothing here reads generated
-- output (CMakeLists.txt, .clangd).
local M = {}

local markdown = require('core.markdown-table')

M.TOOLCHAIN_MANIFEST = 'cast/CAST.md'

local MANIFEST = 'project-info.md'
local COMPILE_DATABASE = 'compile_commands.json'
local JUCE_HEADER = 'JuceLibraryCode/JuceHeader.h'
local DEFAULT_ARGUMENT = 'default'
local DEBUGGER = 'whatdbg'

-- The manifest contract: every table and every ## cmake key the AST is
-- built from. A manifest missing any of them is not a project.
local REQUIRED_TABLES = { 'index', 'project info', 'cmake', 'toolchain' }
local REQUIRED_CMAKE_KEYS = { 'jucePath', 'userModulePath', 'targetName', 'productName', 'juceTargetFunction', 'bundleIdentifier' }

local is_windows = vim.fn.has('win32') == 1
local PLATFORM = is_windows and 'win' or 'mac'

-- JUCE's fixed per-format artefact layout. {artefacts} is
-- <buildDir>/<targetName>_artefacts/<buildType> -- JUCE names the artefact
-- directory after the CMake target, which the manifest declares separately
-- from the product name it may not be a legal identifier for -- and {name}
-- is the PRODUCT_NAME.
-- A format without an entry for the host platform is not a target there.
local FORMAT_LAYOUT = {
  Standalone = { kind = 'executable',
                 mac = '{artefacts}/Standalone/{name}.app/Contents/MacOS/{name}',
                 win = '{artefacts}/Standalone/{name}.exe' },
  VST3 = { kind = 'plugin',
           mac = '{artefacts}/VST3/{name}.vst3/Contents/MacOS/{name}',
           win = '{artefacts}/VST3/{name}.vst3/Contents/x86_64-win/{name}.vst3' },
  AU = { kind = 'plugin',
         mac = '{artefacts}/AU/{name}.component/Contents/MacOS/{name}' },
  AAX = { kind = 'plugin',
          mac = '{artefacts}/AAX/{name}.aaxplugin/Contents/MacOS/{name}',
          win = '{artefacts}/AAX/{name}.aaxplugin/Contents/x64/{name}.aaxplugin' },
  VST = { kind = 'plugin',
          mac = '{artefacts}/VST/{name}.vst/Contents/MacOS/{name}',
          win = '{artefacts}/VST/{name}.dll' },
  CLAP = { kind = 'plugin',
           mac = '{buildDir}/{name}.clap/Contents/MacOS/{name}',
           win = '{buildDir}/{name}.clap' },
}

-- Non-plugin JUCE target functions produce exactly one artefact.
local APPLICATION_LAYOUT = {
  juce_add_console_app = { kind = 'executable',
                           mac = '{artefacts}/{name}',
                           win = '{artefacts}/{name}.exe' },
  juce_add_gui_app = { kind = 'executable',
                       mac = '{artefacts}/{name}.app/Contents/MacOS/{name}',
                       win = '{artefacts}/{name}.exe' },
}

local CAPABILITIES = {
  executable = { run = true, debug = true },
  plugin = { run = false, debug = true },
}

-- Plugins attach to a running host on macOS; on Windows the debugger
-- launches the host itself so every DLL load is tracked from birth.
local LAUNCH = {
  executable = { adapter = DEBUGGER, request = 'launch' },
  plugin = { adapter = DEBUGGER, request = is_windows and 'launch' or 'attach' },
}

-- Token count consumed by compile-command flags that never reach .clangd.
-- --target is dropped because LLVM triple parsing is case-sensitive and
-- CMake's Windows toolchain emits AMD64-pc-windows-msvc; clangd infers the
-- native triple from the compiler binary itself.
local FLAG_SKIP = { ['-o'] = 2, ['-c'] = 1, ['-target'] = 2 }

-- A manifest cell authored as a code span (`...`) yields the span's
-- content -- what jam::MarkdownDocument::getTableValues() yields, and what
-- CAST renders for it.
local function getContent(cell)
  return cell:match('^`(.*)`$') or cell
end

-- A two-column table as key -> value.
local function getValuesByKey(parsedTable, keyHeader, valueHeader)
  local values = {}
  for _, record in ipairs(markdown.getRecords(parsedTable)) do
    values[record[keyHeader]] = getContent(record[valueHeader])
  end
  return values
end

-- A manifest path value as an absolute path: the @alias resolved, then
-- every ${VARIABLE} / $ENV{NAME} reference.
local function getPath(value, aliases, variables)
  local text = aliases[value] or value
  text = text:gsub('%$ENV{([%w_]+)}', function(name) return os.getenv(name) or '' end)
  text = text:gsub('%${([%w_]+)}', function(name) return variables[name] or '' end)
  return vim.fn.simplify(text)
end

local function render(layout, values)
  return (layout:gsub('{(%w+)}', values))
end

local function getConfigurations(root, toolchain)
  local configurations = {}
  for _, record in ipairs(markdown.getRecords(toolchain)) do
    if record.command == 'cmake' then
      local key = record.argument == '' and DEFAULT_ARGUMENT or record.argument
      configurations[key] = {
        argument = record.argument,
        buildType = record.flag:match('CMAKE_BUILD_TYPE=(%S+)'),
        buildDir = vim.fn.simplify(root .. '/' .. record.flag:match('%-B%s+(%S+)')),
      }
    end
  end
  return configurations
end

local function getLayouts(cmake, formats)
  if formats then
    local layouts = {}
    for _, format in ipairs(markdown.getColumn(formats, 'value')) do
      layouts[#layouts + 1] = { name = format, layout = FORMAT_LAYOUT[format] }
    end
    return layouts
  end
  return { { name = cmake.productName, layout = APPLICATION_LAYOUT[cmake.juceTargetFunction] } }
end

local function getProduct(layout, configurations, targetName, productName)
  local product = {}
  for key, configuration in pairs(configurations) do
    product[key] = render(layout, {
      artefacts = configuration.buildDir .. '/' .. targetName .. '_artefacts/' .. configuration.buildType,
      buildDir = configuration.buildDir,
      name = productName,
    })
  end
  return product
end

local function getTargets(cmake, formats, configurations)
  local targets = {}
  for _, entry in ipairs(getLayouts(cmake, formats)) do
    local layout = entry.layout and entry.layout[PLATFORM]
    if layout then
      targets[#targets + 1] = {
        name = entry.name,
        kind = entry.layout.kind,
        capabilities = vim.deepcopy(CAPABILITIES[entry.layout.kind]),
        product = getProduct(layout, configurations, cmake.targetName, cmake.productName),
      }
    end
  end
  return targets
end

local function getLaunch(targets)
  local launch = {}
  for _, target in ipairs(targets) do
    launch[target.name] = vim.deepcopy(LAUNCH[target.kind])
  end
  return launch
end

-- Each ## user module row names its own root: the module lives at
-- <root>/<name>.
local function getUserModules(parsedTable, aliases, variables)
  local modules = {}
  for _, record in ipairs(markdown.getRecords(parsedTable)) do
    modules[#modules + 1] = { name = record.name, root = getPath(record.root, aliases, variables) .. '/' .. record.name }
  end
  return modules
end

-- Extracts every distinct compiler flag from one representative
-- compile-database entry, in command order. Two-token flags (-arch arm64)
-- stay two consecutive entries. Both CDB spellings are read: the
-- `arguments` array, or the single `command` string.
local function getFlags(entry)
  local tokens = entry.arguments or vim.split(entry.command, '%s+', { trimempty = true })
  local flags, seen = {}, {}
  local index = 2
  while index <= #tokens do
    local token, following = tokens[index], tokens[index + 1]
    local skip = FLAG_SKIP[token] or (token:find('^%-%-target=') and 1) or (token == entry.file and 1)
    if skip then
      index = index + skip
    elseif token:sub(1, 1) == '-' then
      local hasArgument = following ~= nil and following:sub(1, 1) ~= '-'
        and not token:find('=', 1, true) and following ~= entry.file
      local key = hasArgument and (token .. ' ' .. following) or token
      if not seen[key] then
        seen[key] = true
        flags[#flags + 1] = token
        if hasArgument then flags[#flags + 1] = following end
      end
      index = index + (hasArgument and 2 or 1)
    else
      index = index + 1
    end
  end
  return flags
end

local function getCompile(configurations, targetName)
  local compile = {}
  for key, configuration in pairs(configurations) do
    local database = configuration.buildDir .. '/' .. COMPILE_DATABASE
    if vim.fn.filereadable(database) == 1 then
      local entries = vim.json.decode(table.concat(vim.fn.readfile(database), '\n'))
      assert(entries[1], 'cast: empty compile database ' .. database)
      local juceHeader = configuration.buildDir .. '/' .. targetName .. '_artefacts/' .. JUCE_HEADER
      compile[key] = {
        database = database,
        flags = getFlags(entries[1]),
        juceHeader = vim.fn.filereadable(juceHeader) == 1 and juceHeader or nil,
      }
    end
  end
  return compile
end

-- Every file the AST was built from, once each: the manifest and each
-- distinct compile database (configurations may share a build directory).
local function getSources(manifest, compile)
  local sources, seen = { manifest }, { [manifest] = true }
  local keys = vim.tbl_keys(compile)
  table.sort(keys)
  for _, key in ipairs(keys) do
    local database = compile[key].database
    if not seen[database] then
      seen[database] = true
      sources[#sources + 1] = database
    end
  end
  return sources
end

local function getTablesByHeading(manifest)
  local tables = markdown.getTables(manifest)
  if not tables then return nil, MANIFEST .. ' not found' end

  local byHeading = {}
  for _, parsedTable in ipairs(tables) do byHeading[parsedTable.heading:lower()] = parsedTable end
  for _, heading in ipairs(REQUIRED_TABLES) do
    if not byHeading[heading] then return nil, MANIFEST .. ' has no ## ' .. heading .. ' table' end
  end
  return byHeading
end

local function getCmake(byHeading)
  local cmake = getValuesByKey(byHeading['cmake'], 'key', 'value')
  for _, key in ipairs(REQUIRED_CMAKE_KEYS) do
    if not cmake[key] then return nil, MANIFEST .. ' ## cmake has no ' .. key .. ' row' end
  end
  return cmake
end

-- The CMake variables the manifest's own values reference, in dependency
-- order: the two roots first, since every other path is written in their
-- terms.
local function getVariables(root, cmake, aliases)
  local variables = { CMAKE_CURRENT_SOURCE_DIR = root }
  variables.CAST_JUCE_PATH = getPath(cmake.jucePath, aliases, variables)
  variables.CAST_USER_MODULE_PATH = getPath(cmake.userModulePath, aliases, variables)
  return variables
end

function M.build(root, selection)
  local manifest = root .. '/' .. MANIFEST
  local byHeading, failure = getTablesByHeading(manifest)
  if not byHeading then return nil, failure end
  local cmake, cmakeFailure = getCmake(byHeading)
  if not cmake then return nil, cmakeFailure end

  local aliases = getValuesByKey(byHeading['index'], 'alias', 'symbol')
  local info = getValuesByKey(byHeading['project info'], 'name', 'value')
  local variables = getVariables(root, cmake, aliases)

  local configurations = getConfigurations(root, byHeading['toolchain'])
  local targets = getTargets(cmake, byHeading['format'], configurations)
  local compile = getCompile(configurations, cmake.targetName)

  return {
    sources = getSources(manifest, compile),
    manifest = { root = root, name = info.projectName, version = info.versionString, id = cmake.bundleIdentifier },
    toolchain = { name = 'cast', manifest = M.TOOLCHAIN_MANIFEST },
    dependencies = {
      juce = { root = variables.CAST_JUCE_PATH, modules = markdown.getColumn(byHeading['juce module'], 'value') },
      user = { root = variables.CAST_USER_MODULE_PATH, modules = getUserModules(byHeading['user module'], aliases, variables) },
    },
    configurations = configurations,
    targets = targets,
    launch = getLaunch(targets),
    compile = compile,
    selection = selection,
  }
end

return M
