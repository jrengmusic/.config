-- Picker configuration
return {
  priority = 1000,
  lazy = false,
  setup = function()
    local dashboard = require('core.dashboard')
    require('snacks').setup({
      picker = { enabled = true },
      quickfile = { enabled = true },
      dashboard = {
        enabled = true,
        preset = {
          header = dashboard.header,
        },
        sections = dashboard.sections,
      },
      -- Explicitly disable unused features to suppress healthcheck warnings
      bigfile = { enabled = false },
      explorer = { enabled = false },
      image = { enabled = false },
      input = { enabled = false },
      lazygit = { enabled = false },
      notifier = { enabled = false },
      scope = { enabled = false },
      scroll = { enabled = false },
      statuscolumn = { enabled = false },
      words = { enabled = false },
    })
  end,
}
