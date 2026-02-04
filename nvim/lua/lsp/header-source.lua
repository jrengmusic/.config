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

local function getCppCorrespondingFile(current)
  if current:match('%.cpp$') then
    return current:gsub('%.cpp$', '.h')
  elseif current:match('%.mm$') then
    return current:gsub('%.mm$', '.h')
  elseif current:match('%.h$') then
    local mmFile = current:gsub('%.h$', '.mm')
    if vim.fn.filereadable(mmFile) == 1 then
      return mmFile
    end
    return current:gsub('%.h$', '.cpp')
  elseif current:match('%.hpp$') then
    return current:gsub('%.hpp$', '.cpp')
  elseif current:match('%.cc$') then
    return current:gsub('%.cc$', '.h')
  end
  return nil
end

-- ============================================================================
-- UNIVERSAL SPLIT LOGIC
-- ============================================================================

local function applySplitRatio()
  local totalWidth = vim.o.columns
  vim.cmd('wincmd h')
  vim.cmd('vertical resize ' .. math.floor(totalWidth * 0.6))
end

local function openSplit(leftFile, rightFile)
  local winCount = #vim.api.nvim_tabpage_list_wins(0)

  if winCount == 1 then
    -- Create split: left=leftFile, right=rightFile
    vim.cmd('buffer ' .. vim.fn.bufadd(leftFile))
    vim.cmd('vsplit')
    vim.cmd('buffer ' .. vim.fn.bufadd(rightFile))
    vim.cmd('wincmd h')
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
-- For C++: uses cpp ↔ h pairing
-- For others: uses LSP type_definition as fallback
local function findRelatedFile(currentFile, callback)
  -- First: Try C++ cpp ↔ h pairing
  if isCpp(currentFile) or isHeader(currentFile) then
    local paired = getCppCorrespondingFile(currentFile)
    if paired and vim.fn.filereadable(paired) == 1 then
      callback(paired)
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

  -- Always sync: open split or update existing
  findRelatedFile(current, function(related)
    if related then
      -- Determine order: for C++, cpp on left; otherwise current on left
      local leftFile, rightFile
      if (isCpp(current) or isHeader(current)) then
        leftFile = isCpp(current) and current or related
        rightFile = isCpp(current) and related or current
      else
        leftFile = current
        rightFile = related
      end
      openSplit(leftFile, rightFile)
    end
  end)
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
          local paired = getCppCorrespondingFile(current)
          if paired and vim.fn.filereadable(paired) == 1 then
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
M.getCorrespondingFile = getCppCorrespondingFile

function M.ensureCppHeaderLayout(targetFile, stayOnTarget)
  local other = getCppCorrespondingFile(targetFile)
  if other and vim.fn.filereadable(other) == 1 then
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
