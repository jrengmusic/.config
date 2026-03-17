-- C++ function definition stub generator
-- Parses declaration under cursor and generates definition stub in .cpp file
local M = {}

local function isMacro(line)
  return line:match('^%s*[A-Z_]+%s*%(') ~= nil
end

local function stripLinkageKeywords(returnType)
  if not returnType then return nil end
  -- Remove linkage/storage class keywords that shouldn't appear in definitions
  returnType = returnType:gsub('^%s*static%s+', '')
  returnType = returnType:gsub('^%s*extern%s+', '')
  returnType = returnType:gsub('^%s*inline%s+', '')
  returnType = returnType:gsub('^%s*virtual%s+', '')
  returnType = returnType:gsub('^%s*constexpr%s+', '')
  returnType = returnType:gsub('^%s*consteval%s+', '')
  returnType = returnType:gsub('^%s*explicit%s+', '')
  return returnType
end

local function parseDeclaration(line, className)
  if isMacro(line) then
    return nil
  end

  -- Check if function is inline - should not generate stub
  local isInline = line:match('^%s*inline%s+') ~= nil

  local funcName, params
  local returnType = nil
  local isConstructor = false
  local isDestructor = false
  
  if className then
    local ctorPattern = '^%s*' .. vim.pesc(className) .. '%s*%((.*)%)%s*[;{:]?'
    params = line:match(ctorPattern)
    if params then
      funcName = className
      returnType = ''
      isConstructor = true
    end
    
    if not isConstructor then
      local dtorPattern = '^%s*~' .. vim.pesc(className) .. '%s*%((.*)%)%s*[;{]?'
      params = line:match(dtorPattern)
      if params then
        funcName = '~' .. className
        returnType = ''
        isDestructor = true
      end
    end
  end
  
  if not isConstructor and not isDestructor then
    -- Try to match function declaration with various keyword combinations
    local pattern = '^%s*(.-)%s+([%w_]+)%s*%((.*)%)%s*[;{=]?'
    returnType, funcName, params = line:match(pattern)

    if not returnType or not funcName then
      local virtualPattern = '^%s*virtual%s+(.-)%s+([%w_]+)%s*%((.*)%)%s*[;{=]?'
      returnType, funcName, params = line:match(virtualPattern)
    end

    if not returnType or not funcName then
      local staticPattern = '^%s*static%s+(.-)%s+([%w_]+)%s*%((.*)%)%s*[;{=]?'
      returnType, funcName, params = line:match(staticPattern)
    end

    if not returnType or not funcName then
      local externPattern = '^%s*extern%s+(.-)%s+([%w_]+)%s*%((.*)%)%s*[;{=]?'
      returnType, funcName, params = line:match(externPattern)
    end

    if not returnType or not funcName then
      local inlinePattern = '^%s*inline%s+(.-)%s+([%w_]+)%s*%((.*)%)%s*[;{=]?'
      returnType, funcName, params = line:match(inlinePattern)
    end

    if not returnType or not funcName then
      return nil
    end

    if returnType == '' then
      return nil
    end

    -- Strip all linkage keywords from return type
    returnType = stripLinkageKeywords(returnType)
  end
  
  params = params or ''
  params = params:gsub('%s*override%s*$', '')
  params = params:gsub('%s*const%s*$', '')
  params = params:gsub('%s*final%s*$', '')
  params = params:gsub('%s*=%s*0%s*$', '')
  params = params:gsub('%s*=%s*default%s*$', '')
  params = params:gsub('%s*=%s*delete%s*$', '')
  
  local isConst = line:match('%)%s*const') ~= nil

  return {
    returnType = returnType and returnType:gsub('^%s+', ''):gsub('%s+$', '') or '',
    funcName = funcName,
    params = params:gsub('^%s+', ''):gsub('%s+$', ''),
    isConst = isConst,
    isConstructor = isConstructor,
    isDestructor = isDestructor,
    isInline = isInline,
  }
end

local function findClassName(bufnr)
  local cursorLine = vim.api.nvim_win_get_cursor(0)[1]
  
  for lineNum = cursorLine, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, lineNum - 1, lineNum, false)[1]
    local className = line:match('^%s*class%s+([%w_]+)')
    if className then
      return className
    end
    local structName = line:match('^%s*struct%s+([%w_]+)')
    if structName then
      return structName
    end
  end
  
  return nil
end

local function switchToSource(callback)
  local client = vim.lsp.get_clients({ name = 'clangd' })[1]
  if not client then
    vim.notify('clangd not attached', vim.log.levels.ERROR)
    return
  end
  
  local currentBuf = vim.api.nvim_get_current_buf()
  local params = { uri = vim.uri_from_bufnr(currentBuf) }
  
  client:request('textDocument/switchSourceHeader', params, function(err, result)
    if err or not result then
      vim.notify('Could not find source file', vim.log.levels.ERROR)
      return
    end
    
    local cppFile = vim.uri_to_fname(result)
    local headerSource = require('lsp.header-source')
    headerSource.ensureCppHeaderLayout(cppFile, true)
    
    if callback then
      vim.schedule(callback)
    end
  end, currentBuf)
end

local function findLastClassMethod(lines, className)
  local pattern = '%s*[%w_:%*&%s]+%s+' .. vim.pesc(className) .. '::[%w_]+%s*%('
  local lastMethodEnd = nil
  local braceDepth = 0
  local inMethod = false
  
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      inMethod = true
      braceDepth = 0
    end
    
    if inMethod then
      for _ in line:gmatch('{') do braceDepth = braceDepth + 1 end
      for _ in line:gmatch('}') do braceDepth = braceDepth - 1 end
      
      if braceDepth == 0 and line:match('}') then
        lastMethodEnd = i
        inMethod = false
      end
    end
  end
  
  return lastMethodEnd
end

local function findMethodRange(lines, className, funcName)
  local pattern = '%s*[%w_:%*&%s]+%s+' .. vim.pesc(className) .. '::' .. vim.pesc(funcName) .. '%s*%('
  local startLine = nil
  local endLine = nil
  local braceDepth = 0
  local inMethod = false
  
  for i, line in ipairs(lines) do
    if not inMethod and line:match(pattern) then
      startLine = i
      inMethod = true
      braceDepth = 0
    end
    
    if inMethod then
      for _ in line:gmatch('{') do braceDepth = braceDepth + 1 end
      for _ in line:gmatch('}') do braceDepth = braceDepth - 1 end
      
      if braceDepth == 0 and line:match('}') then
        endLine = i
        break
      end
    end
  end
  
  return startLine, endLine
end

local function toggleCommentRange(buf, startLine, endLine)
  local lines = vim.api.nvim_buf_get_lines(buf, startLine - 1, endLine, false)
  local allCommented = true
  
  for _, line in ipairs(lines) do
    if line:match('^%s*$') then
    elseif not line:match('^%s*//') then
      allCommented = false
      break
    end
  end
  
  local newLines = {}
  for _, line in ipairs(lines) do
    if allCommented then
      table.insert(newLines, (line:gsub('^(%s*)// ?', '%1')))
    else
      if line:match('^%s*$') then
        table.insert(newLines, line)
      else
        table.insert(newLines, (line:gsub('^(%s*)', '%1// ')))
      end
    end
  end
  
  vim.api.nvim_buf_set_lines(buf, startLine - 1, endLine, false, newLines)
  return not allCommented
end

local function findDeclarationRange(bufnr, lineNum)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local startLine = lineNum
  local endLine = lineNum
  
  for i = lineNum, #lines do
    local line = lines[i]
    if line:match(';') or line:match('{') then
      endLine = i
      break
    end
  end
  
  return startLine, endLine
end

function M.toggleCommentPair()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  
  if not filename:match('%.h$') and not filename:match('%.hpp$') then
    vim.notify('Not in a header file', vim.log.levels.WARN)
    return
  end
  
  local className = findClassName(bufnr)
  if not className then
    vim.notify('Could not find class name', vim.log.levels.ERROR)
    return
  end
  
  local cursorPos = vim.api.nvim_win_get_cursor(0)
  local declaration = collectMultilineDeclaration(bufnr, cursorPos[1])

  local decl = parseDeclaration(declaration, className)
  if not decl then
    vim.notify('Could not parse function declaration', vim.log.levels.ERROR)
    return
  end

  local hStart, hEnd = findDeclarationRange(bufnr, cursorPos[1])
  toggleCommentRange(bufnr, hStart, hEnd)
  
  local client = vim.lsp.get_clients({ name = 'clangd' })[1]
  if not client then
    vim.notify(string.format('Toggled comment: %s::%s (header only)', className, decl.funcName), vim.log.levels.INFO)
    return
  end
  
  local params = { uri = vim.uri_from_bufnr(bufnr) }
  client:request('textDocument/switchSourceHeader', params, function(err, result)
    if err or not result then
      vim.notify(string.format('Toggled comment: %s::%s (header only)', className, decl.funcName), vim.log.levels.INFO)
      return
    end
    
    local cppFile = vim.uri_to_fname(result)
    if vim.fn.filereadable(cppFile) ~= 1 then
      vim.notify(string.format('Toggled comment: %s::%s (header only)', className, decl.funcName), vim.log.levels.INFO)
      return
    end
    
    local cppBuf = vim.fn.bufadd(cppFile)
    vim.fn.bufload(cppBuf)
    
    local cppLines = vim.api.nvim_buf_get_lines(cppBuf, 0, -1, false)
    local startLine, endLine = findMethodRange(cppLines, className, decl.funcName)
    
    if startLine and endLine then
      toggleCommentRange(cppBuf, startLine, endLine)
      vim.notify(string.format('Toggled comment: %s::%s', className, decl.funcName), vim.log.levels.INFO)
    else
      vim.notify(string.format('Toggled comment: %s::%s (header only, no cpp def)', className, decl.funcName), vim.log.levels.INFO)
    end
  end, bufnr)
end

local function insertStubAtEnd(stub, className, funcName)
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  local insertLine = findLastClassMethod(lines, className)
  
  if not insertLine then
    for i = #lines, 1, -1 do
      local line = lines[i]:gsub('^%s+', ''):gsub('%s+$', '')
      if line ~= '' then
        insertLine = i
        break
      end
    end
  end
  
  insertLine = insertLine or #lines
  
  local stubLines = vim.split(stub, '\n')
  table.insert(stubLines, 1, '')
  
  vim.api.nvim_buf_set_lines(buf, insertLine, insertLine, false, stubLines)
  
  local cursorLine = insertLine + 3
  vim.api.nvim_win_set_cursor(0, { cursorLine, 4 })
  vim.cmd('startinsert!')
  
  vim.notify(string.format('Generated stub: %s::%s', className, funcName), vim.log.levels.INFO)
end

local function collectClassDeclarations(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local declarations = {}
  local className = nil
  local inClass = false
  local braceDepth = 0
  local skipUntilLine = 0

  for i, line in ipairs(lines) do
    -- Skip lines that were already processed as part of multi-line declaration
    if i <= skipUntilLine then
      goto continue
    end

    local classMatch = line:match('^%s*class%s+([%w_]+)')
    local structMatch = line:match('^%s*struct%s+([%w_]+)')

    if classMatch then
      className = classMatch
      inClass = true
      braceDepth = 0
    elseif structMatch then
      className = structMatch
      inClass = true
      braceDepth = 0
    end

    if inClass then
      for _ in line:gmatch('{') do braceDepth = braceDepth + 1 end
      for _ in line:gmatch('}') do braceDepth = braceDepth - 1 end

      if braceDepth == 0 and line:match('}') then
        inClass = false
        className = nil
      elseif className and braceDepth > 0 then
        -- Use multi-line collection for parsing
        local fullDecl = collectMultilineDeclaration(bufnr, i)
        local decl = parseDeclaration(fullDecl, className)
        if decl then
          table.insert(declarations, {
            className = className,
            decl = decl,
            line = i,
          })

          -- Calculate how many lines to skip
          local lineCount = 1
          for j = i, #lines do
            if lines[j]:match(';') or lines[j]:match('{') then
              skipUntilLine = j
              break
            end
          end
        end
      end
    end

    ::continue::
  end

  return declarations
end

local function hasDefinition(cppLines, className, funcName)
  local pattern = vim.pesc(className) .. '::' .. vim.pesc(funcName) .. '%s*%('
  for _, line in ipairs(cppLines) do
    if line:match(pattern) and not line:match('^%s*//') then
      return true
    end
  end
  return false
end

local function formatStub(decl, className)
  local constSuffix = decl.isConst and ' const' or ''
  
  if decl.isConstructor or decl.isDestructor then
    return string.format(
      '%s::%s(%s)\n{\n    \n}',
      className,
      decl.funcName,
      decl.params
    )
  else
    return string.format(
      '%s %s::%s(%s)%s\n{\n    \n}',
      decl.returnType,
      className,
      decl.funcName,
      decl.params,
      constSuffix
    )
  end
end

function M.generateAllStubs()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  
  if not filename:match('%.h$') and not filename:match('%.hpp$') then
    vim.notify('Not in a header file', vim.log.levels.WARN)
    return
  end
  
  local declarations = collectClassDeclarations(bufnr)
  if #declarations == 0 then
    vim.notify('No function declarations found', vim.log.levels.WARN)
    return
  end
  
  local client = vim.lsp.get_clients({ name = 'clangd' })[1]
  if not client then
    vim.notify('clangd not attached', vim.log.levels.ERROR)
    return
  end
  
  local params = { uri = vim.uri_from_bufnr(bufnr) }
  client:request('textDocument/switchSourceHeader', params, function(err, result)
    if err or not result then
      vim.notify('Could not find source file', vim.log.levels.ERROR)
      return
    end
    
    local cppFile = vim.uri_to_fname(result)
    local headerSource = require('lsp.header-source')
    headerSource.ensureCppHeaderLayout(cppFile, true)
    
    vim.schedule(function()
      local cppBuf = vim.api.nvim_get_current_buf()
      local cppLines = vim.api.nvim_buf_get_lines(cppBuf, 0, -1, false)
      
      local generated = 0
      local skipped_inline = 0
      for _, entry in ipairs(declarations) do
        -- Skip inline functions
        if entry.decl.isInline then
          skipped_inline = skipped_inline + 1
        elseif not hasDefinition(cppLines, entry.className, entry.decl.funcName) then
          local stub = formatStub(entry.decl, entry.className) .. '\n'
          
          cppLines = vim.api.nvim_buf_get_lines(cppBuf, 0, -1, false)
          local insertLine = findLastClassMethod(cppLines, entry.className)
          
          if not insertLine then
            for i = #cppLines, 1, -1 do
              if cppLines[i]:gsub('^%s+', ''):gsub('%s+$', '') ~= '' then
                insertLine = i
                break
              end
            end
          end
          insertLine = insertLine or #cppLines
          
          local stubLines = vim.split(stub, '\n')
          table.insert(stubLines, 1, '')
          vim.api.nvim_buf_set_lines(cppBuf, insertLine, insertLine, false, stubLines)
          
          generated = generated + 1
        end
      end
      
      local msg = ''
      if generated > 0 then
        msg = string.format('Generated %d stub(s)', generated)
      else
        msg = 'All functions already have definitions'
      end

      if skipped_inline > 0 then
        msg = msg .. string.format(' (skipped %d inline)', skipped_inline)
      end

      vim.notify(msg, vim.log.levels.INFO)
    end)
  end, bufnr)
end

local function collectMultilineDeclaration(bufnr, startLine)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local collected = {}
  local parenDepth = 0
  local foundStart = false

  for i = startLine, #lines do
    local line = lines[i]

    -- Count parentheses
    for char in line:gmatch('.') do
      if char == '(' then
        parenDepth = parenDepth + 1
        foundStart = true
      elseif char == ')' then
        parenDepth = parenDepth - 1
      end
    end

    table.insert(collected, line)

    -- Stop when we've closed all parentheses and found a semicolon or brace
    if foundStart and parenDepth == 0 and (line:match(';') or line:match('{')) then
      break
    end

    -- Safety limit: don't read more than 20 lines
    if #collected >= 20 then
      break
    end
  end

  -- Join lines, preserving single spaces between them
  local joined = table.concat(collected, ' ')
  -- Clean up multiple spaces
  joined = joined:gsub('%s+', ' ')

  return joined
end

function M.generateStub()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if not filename:match('%.h$') and not filename:match('%.hpp$') then
    vim.notify('Not in a header file', vim.log.levels.WARN)
    return
  end

  local className = findClassName(bufnr)
  if not className then
    vim.notify('Could not find class name', vim.log.levels.ERROR)
    return
  end

  local cursorPos = vim.api.nvim_win_get_cursor(0)
  local declaration = collectMultilineDeclaration(bufnr, cursorPos[1])

  local decl = parseDeclaration(declaration, className)
  if not decl then
    vim.notify('Could not parse function declaration', vim.log.levels.ERROR)
    return
  end

  -- Skip inline functions - they should be defined in the header
  if decl.isInline then
    vim.notify('Inline functions should be defined in the header', vim.log.levels.WARN)
    return
  end

  local stub = formatStub(decl, className)
  local funcName = decl.funcName

  switchToSource(function()
    insertStubAtEnd(stub, className, funcName)
  end)
end

return M
