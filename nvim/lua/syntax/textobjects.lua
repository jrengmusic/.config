-- Treesitter textobjects config
local M = {}

function M.setup()
  require('nvim-treesitter-textobjects').setup({
    select = {
      lookahead = true,
    },
  })

  require('core.keymaps').setupTextobjects()
end

return M
