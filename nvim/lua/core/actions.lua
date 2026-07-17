-- core/actions.lua
-- Editor-level keymap actions. Bodies only — bindings live in core/keymaps.lua
-- (generated from nvim/doc/KEYMAPS.md; rows reference these as @actions.*).
local M = {}

local function write_modified_named_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified and vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= '' then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd('write')
      end)
    end
  end
end

function M.saveAllAndQuit()
  write_modified_named_buffers()
  vim.cmd('qa!')
end

function M.smart_quit()
  -- Check if any buffers are modified
  local modified_bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= '' then
        table.insert(modified_bufs, vim.fn.fnamemodify(name, ':t'))
      else
        table.insert(modified_bufs, '[No Name]')
      end
    end
  end

  if #modified_bufs > 0 then
    -- Show modified files and prompt
    local msg = 'Modified buffers:\n' .. table.concat(modified_bufs, '\n') .. '\n\nSave all or discard all?'
    local choice = vim.fn.confirm(msg, '&Save All\n&Discard All\n&Cancel', 3)

    if choice == 1 then
      write_modified_named_buffers()
      vim.cmd('qa!')
    elseif choice == 2 then
      -- Discard all and quit
      vim.cmd('qa!')
    end
    -- choice == 3 or 0 (cancelled): do nothing
  else
    vim.cmd('qa!')
  end
end

-- Fire split sync once on the next BufEnter, but only if the file actually changed.
-- Used by all picker/navigation keymaps so opening a file always syncs the split layout.
function M.splitSyncOnce()
  local fileBefore = vim.fn.expand('%:p')
  vim.api.nvim_create_autocmd('BufEnter', {
    group = vim.api.nvim_create_augroup('split_sync_once', { clear = true }),
    once = true,
    callback = function()
      local fileAfter = vim.fn.expand('%:p')
      if fileAfter ~= fileBefore and fileAfter ~= '' then
        vim.schedule(function()
          require('lsp.header-source').ensureCppHeaderLayout(vim.fn.expand('%:p'))
        end)
      end
    end,
  })
end

function M.toggleDiagnosticList()
  -- Check if location list is open
  local is_open = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == 'quickfix' then
      is_open = true
      break
    end
  end

  if is_open then
    vim.cmd('lclose')
  else
    vim.diagnostic.setloclist({ open = false })
    vim.cmd('topleft lopen 15')
  end
end

function M.closeAllTerminals()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == 'terminal' then
      vim.api.nvim_win_close(win, true)
    end
  end
end

-- Feed a jumplist motion, then re-sync the C++ header/source split layout.
local function jumpSynced(motion)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(motion, true, false, true), 'n', false)
  vim.schedule(function()
    vim.cmd('only')
    require('lsp.header-source').ensureCppHeaderLayout(vim.fn.expand('%:p'))
  end)
end

function M.jumpBackSynced()
  jumpSynced('<C-o>')
end

function M.jumpForwardSynced()
  jumpSynced('<C-i>')
end

-- Dispatches to the C++ clang-format path or conform by filetype.
function M.formatBufferByFiletype()
  local filetype = vim.bo.filetype
  if filetype == 'cpp' or filetype == 'c' or filetype == 'objc' or filetype == 'objcpp' then
    require('core.formatting').formatBuffer()
  else
    require('core.formatting').formatWithConform()
  end
end

-- expr mapping: leave insert/visual mode, then format if the buffer was modified.
function M.formatOnEsc()
  local filetype = vim.bo.filetype
  local was_modified = vim.bo.modified

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)

  -- Only format if buffer was actually modified
  if was_modified then
    vim.schedule(function()
      if filetype == 'cpp' or filetype == 'c' or filetype == 'objc' or filetype == 'objcpp' then
        require('core.formatting').formatBuffer()
      else
        require('core.formatting').formatWithConform()
      end
    end)
  end

  return ''
end

-- expr mapping: jump out of nested ) or } and append ;
function M.jumpOutSemicolon()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local line = vim.api.nvim_get_current_line()
  local count = 0
  local pos = col + 1
  while line:sub(pos, pos):match('[%)%}]') do
    count = count + 1
    pos = pos + 1
  end
  if count > 0 then
    return string.rep('<Right>', count) .. ';'
  else
    return ';'
  end
end

function M.cycleSnippetChoice()
  local luasnip = require('luasnip')
  if luasnip.choice_active() then
    luasnip.change_choice(1)
  end
end

return M
