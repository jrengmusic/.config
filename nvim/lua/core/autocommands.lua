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
end

return M
