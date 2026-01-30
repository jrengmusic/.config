-- Autocommands
local M = {}

function M.setup()
  -- Highlight on yank
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking text',
    group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
    callback = function()
      vim.highlight.on_yank()
    end,
  })

  -- Format on mode change (command to normal)
  vim.api.nvim_create_autocmd('ModeChanged', {
    pattern = { 'c:n' },
    callback = function()
      if not vim.bo.modifiable or vim.bo.buftype ~= '' then
        return
      end
      local filetype = vim.bo.filetype
      if filetype == 'cpp' or filetype == 'c' or filetype == 'objc' or filetype == 'objcpp' then
        vim.schedule(function()
          require('core.formatting').formatBuffer()
        end)
      else
        vim.schedule(function()
          require('core.formatting').formatWithConform()
        end)
      end
    end,
    desc = 'Format on mode change',
  })

  -- Format C/C++ on save
  vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = { '*.cpp', '*.c', '*.h', '*.hpp', '*.objc', '*.objcpp' },
    callback = function()
      require('core.formatting').formatBuffer()
    end,
    desc = 'Format C/C++ on save',
  })

  -- Terminal error highlighting
  vim.api.nvim_create_autocmd('TermOpen', {
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      
      -- Highlight error indicators (^^^^^^^ and ~~~~~~~ lines)
      vim.api.nvim_buf_call(buf, function()
        vim.fn.matchadd('TerminalCaret', '\\^\\+')
        vim.fn.matchadd('ErrorMsg', '\\~\\+')
        vim.fn.matchadd('DiagnosticError', '\\^\\+\\s*$')
        vim.fn.matchadd('DiagnosticError', '\\~\\+\\s*$')
      end)
      
      -- Also highlight common compiler error patterns
      vim.api.nvim_buf_call(buf, function()
        vim.fn.matchadd('DiagnosticError', '\\cerror:')
        vim.fn.matchadd('DiagnosticWarn', '\\cwarning:')
        vim.fn.matchadd('DiagnosticInfo', '\\cnote:')
        
        -- Highlight file paths, filenames, and line/column numbers
        -- Match "from /path/to/filename.ext:" patterns
        
        -- Just the filename (last part of path) with cyan color
        vim.api.nvim_set_hl(0, 'TerminalFilename', { fg = '#00FFFF', bold = false })
        vim.fn.matchadd('TerminalFilename', '\\w\\+\\.\\w\\+\\ze:\\d')
        
        -- Line number in green
        vim.fn.matchadd('TerminalLineNumber', ':\\zs\\d\\+\\ze:')
        
        -- Column number in yellow
        vim.fn.matchadd('DiagnosticWarn', ':\\d\\+:\\zs\\d\\+')
      end)
    end,
    desc = 'Highlight error indicators in terminal',
  })
end

return M
