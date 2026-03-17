-- UI configuration (lualine, mini.nvim)
return {
  setup = function()
    require('lualine').setup({
      options = {
        icons_enabled = true,
        theme = 'auto',
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        disabled_filetypes = { statusline = {}, winbar = {} },
        ignore_focus = {},
        always_divide_middle = true,
        always_show_tabline = true,
        globalstatus = false,
        refresh = {
          statusline = 1000,
          tabline = 1000,
          winbar = 1000,
          refresh_time = 16,
          events = {
            'WinEnter', 'BufEnter', 'BufWritePost', 'SessionLoadPost',
            'FileChangedShellPost', 'VimResized', 'Filetype',
            'CursorMoved', 'CursorMovedI', 'ModeChanged',
          },
        },
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { 'filename' },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { 'filename' },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {},
      winbar = {},
      inactive_winbar = {},
      extensions = {},
    })

    require('mini.ai').setup({ n_lines = 500 })
    require('mini.surround').setup({
      custom_surroundings = {
        -- No-space parentheses (default ( adds spaces)
        ['('] = { output = { left = '(', right = ')' } },
        [')'] = { output = { left = '(', right = ')' } },
        -- std::move wrapper - use 'm' as trigger
        ['m'] = { output = { left = 'std::move (', right = ')' } },
      },
    })
    require('core.keymaps').setupSurround()
    require('mini.pairs').setup({})
    require('core.keymaps').setupMiniPairs()
    local statusline = require('mini.statusline')
    statusline.setup({ use_icons = vim.g.have_nerd_font })
    statusline.section_location = function()
      return '%2l:%-2v'
    end
  end,
}
