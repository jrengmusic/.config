return {
  event = 'VeryLazy',
  setup = function()
    require('core.keymaps').setupFlash()
  end,
  opts = {
    modes = {
      char = {
        enabled = true,
        jump_labels = true,
        label = { rainbow = { enabled = true } },
      },
    },
  },
}
