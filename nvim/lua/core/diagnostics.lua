-- LSP Diagnostics Configuration (Xcode-like experience)
local M = {}

function M.setup()
  -- Configure diagnostic display
  vim.diagnostic.config({
    virtual_text = {
      spacing = 4,
      prefix = '●',
      severity = vim.diagnostic.severity.ERROR, -- Only show errors inline (less noise)
    },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = '✘',
        [vim.diagnostic.severity.WARN] = '▲',
        [vim.diagnostic.severity.HINT] = '⚑',
        [vim.diagnostic.severity.INFO] = '»',
      },
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
      focusable = false,
      style = 'minimal',
      border = 'rounded',
      source = 'always',
      header = '',
      prefix = '',
    },
  })

  -- Auto-close diagnostic list when all errors are fixed
  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = vim.api.nvim_create_augroup('diagnostic-list', { clear = true }),
    callback = function()
      -- Check if diagnostic window is open
      local is_open = false
      local wins = vim.api.nvim_list_wins()
      for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == 'quickfix' then
          is_open = true
          break
        end
      end

      -- Only auto-close if it's open and there are no more errors
      if is_open then
        local diagnostics = vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
        if #diagnostics == 0 then
          pcall(vim.cmd, 'lclose')
        else
          -- Update the list if still open
          vim.diagnostic.setloclist({ open = false })
        end
      end
    end,
  })

  -- Keybindings for diagnostic/quickfix windows
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'qf',
    group = vim.api.nvim_create_augroup('diagnostic-keys', { clear = true }),
    callback = function(event)
      local opts = { buffer = event.buf, silent = true }

      -- Enter: Jump to file and line (stay in diagnostic window)
      vim.keymap.set('n', '<CR>', '<CR>', vim.tbl_extend('force', opts, { desc = 'Jump to diagnostic' }))

      -- q: Close diagnostic window manually
      vim.keymap.set('n', 'q', '<cmd>lclose<CR>', vim.tbl_extend('force', opts, { desc = 'Close diagnostic list' }))

      -- p: Preview diagnostic (peek without jumping)
      vim.keymap.set('n', 'p', '<CR><C-w>p', vim.tbl_extend('force', opts, { desc = 'Preview diagnostic' }))
    end,
  })

  -- Show floating diagnostic on cursor hold
  vim.api.nvim_create_autocmd('CursorHold', {
    group = vim.api.nvim_create_augroup('diagnostic-float', { clear = true }),
    callback = function()
      local opts = {
        focusable = false,
        close_events = { 'BufLeave', 'CursorMoved', 'InsertEnter', 'FocusLost' },
        border = 'rounded',
        source = 'always',
        prefix = ' ',
        scope = 'cursor',
      }
      vim.diagnostic.open_float(nil, opts)
    end,
  })
end

return M
