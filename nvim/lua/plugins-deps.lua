-- Shared dependency groups
return {
  ui = {
    'nvim-tree/nvim-web-devicons',
    'MunifTanjim/nui.nvim',
  },
  lsp = {
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    'hrsh7th/cmp-nvim-lsp',
  },
  notify = {
    'MunifTanjim/nui.nvim',
    {
      'rcarriga/nvim-notify',
      opts = {
        background_colour = '#000000',
      },
    },
  },
  dap = {
    'jay-babu/mason-nvim-dap.nvim',
    {
      'rcarriga/nvim-dap-ui',
      dependencies = {
        'nvim-neotest/nvim-nio',
      },
    },
    'theHamsta/nvim-dap-virtual-text',
  },
  snippets = {
    'rafamadriz/friendly-snippets',
  },
}
