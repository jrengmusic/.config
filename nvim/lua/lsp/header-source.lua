-- Universal split management for any language
-- SSOT: Single Source of Truth for splitting and related files
local M = {}

-- ============================================================================
-- C++ SPECIFIC HELPERS
-- ============================================================================

local function isCpp(file)
  return file:match('%.cpp$') or file:match('%.cc$') or file:match('%.mm$')
end

local function isHeader(file)
  return file:match('%.h$') or file:match('%.hpp$')
end

local function getAllCorrespondingFiles(current)
  local files = {}
  local basename = current:match('(.+)%.[^%.]+$') -- remove extension
  
  if not basename then return files end
  
  -- Check all possible extensions
  local extensions = { '.cpp', '.mm', '.h', '.hpp' }
  for _, ext in ipairs(extensions) do
    local candidate = basename .. ext
    if vim.fn.filereadable(candidate) == 1 and candidate ~= current then
      table.insert(files, candidate)
    end
  end
  
  return files
end

local function getNextInCycle(currentFile, candidateFiles, currentOtherFile)
  if #candidateFiles == 0 then return nil end
  if #candidateFiles == 1 then return candidateFiles[1] end
  
  -- Find current index
  local currentIdx = nil
  for i, file in ipairs(candidateFiles) do
    if file == currentOtherFile then
      currentIdx = i
      break
    end
  end
  
  if currentIdx then
    -- Cycle to next
    local nextIdx = (currentIdx % #candidateFiles) + 1
    return candidateFiles[nextIdx]
  else
    -- Not found, return first
    return candidateFiles[1]
  end
end

-- ============================================================================
-- UNIVERSAL SPLIT LOGIC
-- ============================================================================

local function applySplitRatio()
  vim.cmd('wincmd =')  -- 50/50 split
end

local function openSplit(leftFile, rightFile)
  local winCount = #vim.api.nvim_tabpage_list_wins(0)

  if winCount == 1 then
    -- Create split: left=leftFile, right=rightFile
    vim.cmd('vsplit')
    -- Right window is now active, load rightFile there
    vim.cmd('buffer ' .. vim.fn.bufadd(rightFile))
    -- Switch to left window and load leftFile
    vim.cmd('wincmd h')
    vim.cmd('buffer ' .. vim.fn.bufadd(leftFile))
  else
    -- Update existing split: left=leftFile, right=rightFile
    vim.cmd('wincmd h')
    vim.cmd('buffer ' .. vim.fn.bufadd(leftFile))
    vim.cmd('wincmd l')
    vim.cmd('buffer ' .. vim.fn.bufadd(rightFile))
    vim.cmd('wincmd h')
  end

  applySplitRatio()
end

local function closeSplit()
  vim.cmd('only')
end

-- ============================================================================
-- MAIN PUBLIC API (SSOT)
-- ============================================================================

-- Try to find a related file for ANY language
-- For C++: uses new cycling logic
-- For others: uses LSP type_definition as fallback
local function findRelatedFile(currentFile, callback)
  -- First: Try C++ file pairing
  if isCpp(currentFile) or isHeader(currentFile) then
    local allFiles = getAllCorrespondingFiles(currentFile)
    if #allFiles > 0 then
      callback(allFiles[1]) -- return first match
      return
    end
  end

  -- Fallback: Use LSP type_definition for any language
  vim.lsp.buf.type_definition({
    on_list = function(options)
      if not options.items or #options.items == 0 then
        vim.notify('No related file found', vim.log.levels.WARN)
        return
      end

      local item = options.items[1]
      local relatedFile = item.filename or vim.api.nvim_buf_get_name(item.bufnr)
      callback(relatedFile)
    end,
  })
end

function M.syncSplit()
  local current = vim.fn.expand('%:p')

  if not (isCpp(current) or isHeader(current)) then
    vim.notify('syncSplit only works with C++/header files', vim.log.levels.WARN)
    return
  end

  local allFiles = getAllCorrespondingFiles(current)
  if #allFiles == 0 then
    vim.notify('No corresponding files found', vim.log.levels.WARN)
    return
  end

  -- Count only non-terminal windows
  local normalWins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype ~= 'terminal' then
      table.insert(normalWins, win)
    end
  end
  local winCount = #normalWins

  -- Count only windows with actual files (for toggle logic)
  local fileWinCount = 0
  for _, win in ipairs(normalWins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bufName = vim.api.nvim_buf_get_name(buf)
    if bufName ~= '' and vim.fn.filereadable(bufName) == 1 then
      fileWinCount = fileWinCount + 1
    end
  end

  -- Check if we already have a split with corresponding file (ignore terminals and empty buffers)
  local currentOtherFile = nil
  local currentWin = vim.api.nvim_get_current_win()
  if winCount >= 2 then
    for _, win in ipairs(normalWins) do
      if win ~= currentWin then
        local buf = vim.api.nvim_win_get_buf(win)
        local otherFile = vim.api.nvim_buf_get_name(buf)
        -- Only consider actual files (not empty buffers)
        if otherFile ~= '' and vim.fn.filereadable(otherFile) == 1 then
          currentOtherFile = otherFile
          break
        end
      end
    end
  end

  -- If multiple windows but no valid files, treat as single window
  if fileWinCount >= 2 and currentOtherFile == nil then
    fileWinCount = 1
  end

  -- Check if current split already has the paired file
  local isPaired = false
  if currentOtherFile then
    for _, file in ipairs(allFiles) do
      if vim.fn.fnamemodify(file, ':p') == vim.fn.fnamemodify(currentOtherFile, ':p') then
        isPaired = true
        break
      end
    end
  end

  -- TOGGLE behavior: only toggle when exactly 2 file windows with paired files
  if fileWinCount == 2 and isPaired then
    vim.cmd('only')
    return
  end

  -- Determine target file BEFORE creating/updating split
  local targetFile

  if isHeader(current) then
    -- Header (right side): cycle through cpp/mm files on left
    local leftCandidates = {}
    for _, file in ipairs(allFiles) do
      if isCpp(file) then
        table.insert(leftCandidates, file)
      end
    end
    targetFile = getNextInCycle(current, leftCandidates, currentOtherFile)
  elseif current:match('%.mm$') then
    -- .mm file (left side): cycle through cpp/h files on right
    local rightCandidates = {}
    for _, file in ipairs(allFiles) do
      if not file:match('%.mm$') then -- cpp or h
        table.insert(rightCandidates, file)
      end
    end
    targetFile = getNextInCycle(current, rightCandidates, currentOtherFile)
  else
    -- .cpp file (left side): find header for right side
    for _, file in ipairs(allFiles) do
      if isHeader(file) then
        targetFile = file
        break
      end
    end
  end

  if not targetFile then
    vim.notify('No target file found', vim.log.levels.WARN)
    return
  end

  -- Determine layout: h always right, cpp/mm always left
  local leftFile, rightFile
  if isHeader(current) then
    leftFile = targetFile
    rightFile = current
  else
    leftFile = current
    rightFile = targetFile
  end

  -- Create split if only 1 file window, then load files immediately
  if fileWinCount == 1 then
    -- Verify target file exists
    if vim.fn.filereadable(targetFile) ~= 1 then
      vim.notify('Target file not found: ' .. targetFile, vim.log.levels.ERROR)
      return
    end

    -- Strategy: Always create split with cpp left, header right
    -- Then return to the window we started from

    if isHeader(current) then
      -- Current is header (will go right), target is cpp (goes left)
      vim.cmd('vsplit ' .. vim.fn.fnameescape(targetFile))
      vim.cmd('wincmd H')  -- Move current window to far left
      vim.cmd('wincmd l')  -- Move to right (header) where we started
    else
      -- Current is cpp (will stay left), target is header (goes right)
      vim.cmd('vsplit ' .. vim.fn.fnameescape(targetFile))
      vim.cmd('wincmd h')  -- Move to left (cpp) where we started
    end

    vim.cmd('wincmd =')  -- Equalize sizes
    return
  end

  -- Update existing split (2+ windows)
  -- Find leftmost and rightmost non-terminal windows
  local leftWin, rightWin
  for _, win in ipairs(normalWins) do
    local pos = vim.api.nvim_win_get_position(win)
    if not leftWin or pos[2] < vim.api.nvim_win_get_position(leftWin)[2] then
      leftWin = win
    end
    if not rightWin or pos[2] > vim.api.nvim_win_get_position(rightWin)[2] then
      rightWin = win
    end
  end

  -- Load files in the correct positions
  vim.api.nvim_set_current_win(leftWin)
  vim.cmd('buffer ' .. vim.fn.bufadd(leftFile))
  if rightWin and rightWin ~= leftWin then
    vim.api.nvim_set_current_win(rightWin)
    vim.cmd('buffer ' .. vim.fn.bufadd(rightFile))
  end

  -- Stay in the window we started from
  if isHeader(current) then
    vim.api.nvim_set_current_win(rightWin)
  else
    vim.api.nvim_set_current_win(leftWin)
  end
end

-- ============================================================================
-- SMART DEFINITION JUMP (split-aware for cpp/h and any language)
-- ============================================================================

function M.smartDefinitionJump()
  local current = vim.fn.expand('%:p')
  local winCount = #vim.api.nvim_tabpage_list_wins(0)

  -- Get adjacent pane info
  local adjacentBuf = nil
  local adjacentWin = nil
  if winCount >= 2 then
    local currentWin = vim.api.nvim_get_current_win()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, win in ipairs(wins) do
      if win ~= currentWin then
        adjacentWin = win
        adjacentBuf = vim.api.nvim_win_get_buf(win)
        break
      end
    end
  end

  -- Handler for LSP definition lookup
  local function handleDefinition(items)
    if not items or #items == 0 then
      vim.notify('No definition found', vim.log.levels.WARN)
      return
    end

    local item = items[1]
    local defFile = item.filename or vim.api.nvim_buf_get_name(item.bufnr)
    local defLine = item.lnum
    local defCol = (item.col or 1) - 1

    if winCount < 2 then
      -- Single pane: just jump
      vim.cmd('buffer ' .. vim.fn.bufadd(defFile))
      if defLine then
        vim.api.nvim_win_set_cursor(0, { defLine, defCol })
      end
    else
      -- Two panes: navigate to adjacent, ensure pair is visible
      local adjacentFile = adjacentBuf and vim.api.nvim_buf_get_name(adjacentBuf) or nil

      -- Check if definition is already in adjacent pane
      if adjacentFile == defFile then
        -- Definition already visible in adjacent pane, just go there
        vim.api.nvim_set_current_win(adjacentWin)
        if defLine then
          vim.api.nvim_win_set_cursor(0, { defLine, defCol })
        end
      else
        -- Definition not visible in adjacent pane
        -- For C++: ensure pair is open first, then show definition
        if isCpp(current) or isHeader(current) then
          local allFiles = getAllCorrespondingFiles(current)
          if #allFiles > 0 then
            local paired = allFiles[1]
            -- Open pair in adjacent pane
            vim.api.nvim_set_current_win(adjacentWin)
            vim.cmd('buffer ' .. vim.fn.bufadd(paired))
            -- Check if definition is in the pair
            if vim.fn.fnamemodify(defFile, ':p') == vim.fn.fnamemodify(paired, ':p') then
              if defLine then
                vim.api.nvim_win_set_cursor(0, { defLine, defCol })
              end
            else
              -- Definition is elsewhere, open it
              vim.cmd('buffer ' .. vim.fn.bufadd(defFile))
              if defLine then
                vim.api.nvim_win_set_cursor(0, { defLine, defCol })
              end
            end
          else
            -- No pair found, just open definition in adjacent
            vim.api.nvim_set_current_win(adjacentWin)
            vim.cmd('buffer ' .. vim.fn.bufadd(defFile))
            if defLine then
              vim.api.nvim_win_set_cursor(0, { defLine, defCol })
            end
          end
        else
          -- Not C++: just open definition in adjacent pane
          vim.api.nvim_set_current_win(adjacentWin)
          vim.cmd('buffer ' .. vim.fn.bufadd(defFile))
          if defLine then
            vim.api.nvim_win_set_cursor(0, { defLine, defCol })
          end
        end
      end
    end
  end

  -- Query LSP for definition
  vim.lsp.buf.definition({
    on_list = function(options)
      handleDefinition(options.items)
    end,
  })
end

-- ============================================================================
-- LEGACY EXPORTS (for backward compatibility with cpp-stub.lua)
-- ============================================================================

M.isCpp = isCpp
M.isHeader = isHeader
-- Legacy function for backward compatibility 
function M.getCorrespondingFile(current)
  local allFiles = getAllCorrespondingFiles(current)
  return allFiles[1] -- return first match for compatibility
end

function M.ensureCppHeaderLayout(targetFile, stayOnTarget)
  local allFiles = getAllCorrespondingFiles(targetFile)
  if #allFiles > 0 then
    local other = allFiles[1] -- use first match
    local leftFile = isCpp(targetFile) and targetFile or other
    local rightFile = isCpp(targetFile) and other or targetFile
    openSplit(leftFile, rightFile)
  else
    vim.cmd('buffer ' .. vim.fn.bufadd(targetFile))
  end
end

function M.toggleHeaderSplit()
  M.syncSplit()
end

function M.gotoDefinitionWithLayout()
  -- No longer used (reverted per user feedback)
  vim.lsp.buf.definition()
end

function M.setup()
  -- Keymaps now in core/keymaps.lua
end

return M
