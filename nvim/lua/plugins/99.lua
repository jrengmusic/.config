-- 99 AI agent configuration (ThePrimeagen)
return {
  setup = function()
    -- Override tmp directory BEFORE loading 99 (it caches the function)
    require('99.utils').random_file = function()
      return string.format('/tmp/99-%d', math.floor(math.random() * 10000))
    end

    local _99 = require('99')

    _99.setup({
      model = 'minimax-coding-plan/MiniMax-M2.1',
      logger = {
        level = _99.INFO,
        print_on_error = true,
      },
      completion = {
        custom_rules = {
          vim.fn.stdpath('config') .. '/rules/',
        },
        source = 'cmp',
      },
      md_files = {
        'AGENTS.md',
        'AGENT.md',
      },
    })

    require('core.keymaps').setup99()
  end,
}
