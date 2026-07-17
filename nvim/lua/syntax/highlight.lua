-- Treesitter core config: filetype registration + highlighting
local M = {}

function M.setup()
  vim.treesitter.language.register('cpp', 'objcpp')

  -- new nvim-treesitter (main branch) only accepts install_dir in setup();
  -- highlight/indent/ensure_installed are dropped — neovim 0.12 owns highlighting natively.
  require('nvim-treesitter.config').setup()

  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      pcall(vim.treesitter.start, args.buf)
    end,
    desc = 'Enable treesitter highlighting',
  })
end

return M
