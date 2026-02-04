-- Centralized keybindings (grouped by feature)
local M = {}

function M.setup()
  -- ============================================================================
  -- GENERAL
  -- ============================================================================
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlights' })
  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic quickfix list' })
  vim.keymap.set('n', 'ZA', '<cmd>wqa!<CR>', { desc = 'Save all and quit' })
  vim.keymap.set('n', '<leader>tt', function() require('core.tui').tit() end, { desc = 'Open TIT (git TUI)' })
  vim.keymap.set('n', '<leader>tc', function() require('core.tui').cake() end, { desc = 'Open Cake TUI' })
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
  
  -- Split commands (<leader>s group)
  vim.keymap.set('n', '<leader>ss', function() require('lsp.header-source').syncSplit() end, { desc = 'Sync header/source split' })
  vim.keymap.set('n', '<leader>s\\', '<C-w>v', { desc = 'Split vertical' })
  vim.keymap.set('n', '<leader>s-', '<C-w>s', { desc = 'Split horizontal' })
  vim.keymap.set('n', '<leader>s=', '<C-w>=', { desc = 'Equal split sizes' })
  vim.keymap.set('n', '<leader><Tab>', '<C-w>o', { desc = 'Close other splits' })

  -- Window navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Focus left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Focus right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Focus lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Focus upper window' })
  vim.keymap.set('n', '<leader>x', '<C-w>q', { desc = 'Close window' })

  -- Jump list navigation
  vim.keymap.set('n', '<leader>[', '<C-o>', { desc = 'Jump back' })
  vim.keymap.set('n', '<leader>]', '<C-i>', { desc = 'Jump forward' })

  -- ============================================================================
  -- FORMATTING
  -- ============================================================================
  local function formatOnEsc()
    local filetype = vim.bo.filetype
    local was_modified = vim.bo.modified
    
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
    
    -- Only format if buffer was actually modified
    if was_modified then
      vim.schedule(function()
        if filetype == 'cpp' or filetype == 'c' or filetype == 'objc' or filetype == 'objcpp' then
          require('core.formatting').formatBuffer()
        else
          require('core.formatting').formatWithConform()
        end
      end)
    end
    
    return ''
  end

  vim.keymap.set('i', '<Esc>', formatOnEsc, { expr = true, desc = 'Format on exit insert mode' })
  vim.keymap.set('v', '<Esc>', formatOnEsc, { expr = true, desc = 'Format on exit visual mode' })

  vim.keymap.set('n', '<Esc><Esc>', function()
    local filetype = vim.bo.filetype
    if filetype == 'cpp' or filetype == 'c' or filetype == 'objc' or filetype == 'objcpp' then
      require('core.formatting').formatBuffer()
    else
      require('core.formatting').formatWithConform()
    end
  end, { desc = 'Format buffer' })

  -- ============================================================================
  -- PICKER (snacks.nvim)
  -- ============================================================================
  vim.keymap.set('n', '<leader>ff', function() require('core.cmake-picker').files() end, { desc = 'Find files (cmake)' })
  vim.keymap.set('n', '<leader>fx', function() require('core.cmake-picker').open_explorer() end, { desc = 'Project explorer (cmake)' })
  vim.keymap.set('n', '<leader>fg', function() Snacks.picker.grep() end, { desc = 'Find by grep' })
  vim.keymap.set('n', '<leader>fb', function() Snacks.picker.buffers() end, { desc = 'Find buffers' })
  vim.keymap.set('n', '<leader>fh', function() Snacks.picker.help() end, { desc = 'Find help' })
  vim.keymap.set('n', '<leader>\\', function() Snacks.picker.explorer() end, { desc = 'File explorer' })
  vim.keymap.set('n', '<leader>fk', function() Snacks.picker.keymaps() end, { desc = 'Find keymaps' })
  vim.keymap.set('n', '<leader>fw', function() Snacks.picker.grep_word() end, { desc = 'Find current word' })
  vim.keymap.set('n', '<leader>fd', function() Snacks.picker.diagnostics() end, { desc = 'Find diagnostics' })
  vim.keymap.set('n', '<leader>fr', function() Snacks.picker.resume() end, { desc = 'Find resume' })
  vim.keymap.set('n', '<leader>f.', function() Snacks.picker.recent() end, { desc = 'Find recent files' })
  vim.keymap.set('n', '<leader>/', function() Snacks.picker.lines() end, { desc = 'Search in buffer' })
  vim.keymap.set('n', '<leader>f/', function() Snacks.picker.grep_buffers() end, { desc = 'Find in open files' })
  vim.keymap.set('n', '<leader>fn', function() Snacks.picker.files({ cwd = vim.fn.stdpath('config') }) end, { desc = 'Find neovim files' })

  -- ============================================================================
  -- LSP
  -- ============================================================================
  -- LSP keymaps are set in LspAttach autocmd (see lsp/clangd.lua)
  -- This section documents the mappings for reference:
  --   gd        → Go to definition (split-aware, smart jump)
  --   gr        → Go to references
  --   gI        → Go to implementation
  --   gD        → Go to declaration
  --   g<Tab>    → Split with definition/type
  --   gh        → Go to header/source (clangd)
  --   K         → Hover documentation
  --   <leader>ds → Document symbols
  --   <leader>ws → Workspace symbols
  --   <leader>rn → Rename symbol
  --   <leader>ca → Code action

  -- ============================================================================
  -- DAP (Debug)
  -- ============================================================================
  -- DAP keymaps are set after dap loads (see dap/ui.lua)
  -- This section documents the mappings for reference:
  --   <F5>       → Start/Continue
  --   <F10>      → Step over
  --   <F11>      → Step into
  --   <F12>      → Step out
  --   <leader>db → Toggle breakpoint
  --   <leader>dB → Conditional breakpoint
  --   <leader>dl → Log point
  --   <leader>dc → Continue
  --   <leader>di → Step into
  --   <leader>do → Step over
  --   <leader>dO → Step out
  --   <leader>dt → Terminate + close DAW
  --   <leader>dr → Open REPL
  --   <leader>dL → Run last
  --   <leader>du → Toggle UI
  --   <leader>de → Evaluate expression
  --   <leader>br → Build + Launch + Attach (auto-detects plugin/standalone)
  --   <leader>bb → Build only (no launch)
  --   <leader>bc → Clean build
  --   <leader>bk → Clean
  --   <F5> → Configure project (auto-detects plugin/standalone)
end

-- LSP keymaps (called from LspAttach)
function M.setupLsp(event)
  local map = function(keys, func, desc, mode)
    mode = mode or 'n'
    vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
  end

  -- General LSP
  map('gd', function() require('lsp.header-source').smartDefinitionJump() end, 'Go to definition')
  map('gr', function() Snacks.picker.lsp_references() end, 'Go to references')
  map('gI', function() Snacks.picker.lsp_implementations() end, 'Go to implementation')
  map('gD', vim.lsp.buf.declaration, 'Go to declaration')
  map('K', vim.lsp.buf.hover, 'Hover documentation')
  map('<leader>ds', function() Snacks.picker.lsp_symbols() end, 'Document symbols')
  map('<leader>ws', function() Snacks.picker.lsp_workspace_symbols() end, 'Workspace symbols')
  map('<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
  map('<leader>ca', vim.lsp.buf.code_action, 'Code action', { 'n', 'x' })

  -- C++ specific keymaps (clangd)
  local client = vim.lsp.get_client_by_id(event.data.client_id)
  if client and client.name == 'clangd' then
    map('gh', '<cmd>ClangdSwitchSourceHeader<CR>', 'Switch header/source')
    map('<leader>cc', function() require('lsp.cpp-stub').generateStub() end, 'Generate C++ definition stub')
    map('<leader>cv', function() require('lsp.cpp-stub').generateAllStubs() end, 'Generate all missing C++ stubs')
    map('<leader>c/', function() require('lsp.cpp-stub').toggleCommentPair() end, 'Toggle comment in header + cpp')
  end

  -- Inlay hints
  if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
    map('<leader>th', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
    end, 'Toggle inlay hints')
  end
end

-- DAP keymaps (called after dap loads)
function M.setupDap()
  local dap = require('dap')
  local dapui = require('dapui')
  local dapConfig = require('dap.configurations')

  local map = function(keys, func, desc)
    vim.keymap.set('n', keys, func, { desc = 'DAP: ' .. desc })
  end

  -- Build functions (extracted for reuse)
  local function runBuildOnly()
    vim.cmd('silent! wa')
    
    local root = vim.fn.getcwd()
    local script = vim.fn.stdpath('config') .. '/scripts/build-debug.sh'
    
    if vim.fn.filereadable(script) ~= 1 then
      vim.notify('build-debug.sh not found in nvim config', vim.log.levels.ERROR)
      return
    end
    
    local dapConfig = require('dap.configurations')
    local projectType = dapConfig.detectProjectType()
    
    local function runBuild(scheme, format)
      local cmd = script .. ' ' .. vim.fn.shellescape(root) .. ' ' .. scheme .. ' ' .. format
      
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == 'terminal' then
          vim.api.nvim_win_close(win, true)
          break
        end
      end
      
      vim.cmd('botright 15split | terminal ' .. cmd)
      
      local term_buf = vim.api.nvim_get_current_buf()
      local term_win = vim.api.nvim_get_current_win()
      
      vim.api.nvim_create_autocmd({'TermRequest', 'TextChangedT', 'CursorMovedI'}, {
        buffer = term_buf,
        callback = function()
          if vim.api.nvim_win_is_valid(term_win) then
            local line_count = vim.api.nvim_buf_line_count(term_buf)
            vim.api.nvim_win_set_cursor(term_win, {line_count, 0})
          end
        end,
      })
      
      vim.cmd('startinsert')
      vim.api.nvim_create_autocmd('TermClose', {
        buffer = term_buf,
        once = true,
        callback = function()
          local exit_code = vim.v.event.status
          if exit_code == 0 then
            if vim.api.nvim_win_is_valid(term_win) then
              vim.api.nvim_win_close(term_win, true)
            end
            vim.cmd('LspRestart')
            vim.notify('Build succeeded, LSP restarted', vim.log.levels.INFO)
          else
            vim.notify('Build failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
          end
        end,
      })
    end
    
    if projectType == 'standalone' then
      local config = dapConfig.loadStandaloneConfig(function(cfg)
        if cfg then runBuild(cfg.buildScheme, 'Standalone') end
      end)
      if config then
        runBuild(config.buildScheme, 'Standalone')
      end
    elseif projectType == 'plugin' then
      local config = dapConfig.loadDawConfig(function(cfg)
        if cfg then runBuild(cfg.buildScheme, cfg.format) end
      end)
      if config then
        runBuild(config.buildScheme, config.format)
      end
    else
      vim.notify('Cannot detect project type. Check CMakeLists.txt or build directory.', vim.log.levels.ERROR)
    end
  end

  local function runCleanOnly()
    local root = vim.fn.getcwd()
    local script = vim.fn.stdpath('config') .. '/scripts/clean-build.sh'
    
    if vim.fn.filereadable(script) ~= 1 then
      vim.notify('clean-build.sh not found in nvim config')
      return
    end

    -- Show clean build output in terminal split
    vim.cmd('botright 20split | terminal ' .. script .. ' ' .. root)
    vim.cmd('startinsert')
  end

  -- Function keys
  -- F5: Always show config dialog (auto-detects plugin vs standalone)
  vim.keymap.set('n', '<F5>', function()
    local projectType = dapConfig.detectProjectType()
    
    if projectType == 'standalone' then
      -- Standalone: only ask for build scheme
      dapConfig.showStandaloneSchemeDialog(function(config)
        if config then
          vim.notify('Standalone config saved. Press <leader><C-r> to build.')
        end
      end)
    elseif projectType == 'plugin' then
      -- Plugin: ask for format + DAW + build scheme
      dapConfig.showDawFormatDialog(function(config)
        if config then
          vim.notify('Plugin config saved. Press <leader><C-r> to build.')
        end
      end)
    else
      vim.notify('Cannot detect project type (plugin or standalone). Check CMakeLists.txt.')
    end
  end, { desc = 'DAP: Configure project' })
  
  map('<F10>', dap.step_over, 'Step over')
  map('<F11>', dap.step_into, 'Step into')
  map('<F12>', dap.step_out, 'Step out')

  -- Leader-d prefix
  map('<leader>db', dap.toggle_breakpoint, 'Toggle breakpoint')
  map('<leader>dB', function() dap.set_breakpoint(vim.fn.input('Condition: ')) end, 'Conditional breakpoint')
  map('<leader>dl', function() dap.set_breakpoint(nil, nil, vim.fn.input('Log message: ')) end, 'Log point')
  map('<leader>dc', dap.continue, 'Continue')
  map('<leader>di', dap.step_into, 'Step into')
  map('<leader>do', dap.step_over, 'Step over')
  map('<leader>dO', dap.step_out, 'Step out')
  map('<leader>dr', function() dap.repl.open() end, 'Open REPL')
  map('<leader>dL', dap.run_last, 'Run last')
  map('<leader>du', dapui.toggle, 'Toggle UI')
  map('<leader>de', dapui.eval, 'Evaluate expression')

  -- Terminate + close DAW/App (auto-detects project type)
  vim.keymap.set('n', '<leader>dt', function()
    dap.terminate()
    
    local projectType = dapConfig.detectProjectType()
    
    if projectType == 'plugin' then
      -- For plugins: also kill the DAW process
      local config = dapConfig.loadDawConfig(function(cfg)
        if cfg and cfg.daw then
          vim.fn.jobstart({ 'killall', cfg.daw })
        end
      end)
      -- If config already exists, kill DAW immediately
      if config and config.daw then
        vim.fn.jobstart({ 'killall', config.daw })
      end
    elseif projectType == 'standalone' then
      -- For standalone: just terminate (no DAW to kill)
      vim.notify('Standalone app terminated')
    end
  end, { desc = 'DAP: Terminate + close DAW/App' })

  -- Visual mode eval
  vim.keymap.set('v', '<leader>de', dapui.eval, { desc = 'DAP: Evaluate selection' })

  -- Build group keymaps
  vim.keymap.set('n', '<leader>br', function()
    -- Auto-save all buffers before building
    vim.cmd('silent! wa')
    
    local root = vim.fn.getcwd()
    local script = vim.fn.stdpath('config') .. '/scripts/build-debug.sh'
    
    if vim.fn.filereadable(script) ~= 1 then
      vim.notify('build-debug.sh not found in nvim config', vim.log.levels.ERROR)
      return
    end

    local projectType = dapConfig.detectProjectType()
    
    -- Shared terminal handler for build process
    local function runBuildInTerminal(cmd, onSuccess)
      -- Reuse existing build terminal if open
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == 'terminal' then
          vim.api.nvim_win_close(win, true)
          break
        end
      end
      
      vim.cmd('botright 15split | terminal ' .. cmd)
      
      local term_buf = vim.api.nvim_get_current_buf()
      local term_win = vim.api.nvim_get_current_win()
      
      -- Auto-scroll terminal output
      vim.api.nvim_create_autocmd({'TermRequest', 'TextChangedT', 'CursorMovedI'}, {
        buffer = term_buf,
        callback = function()
          if vim.api.nvim_win_is_valid(term_win) then
            local line_count = vim.api.nvim_buf_line_count(term_buf)
            vim.api.nvim_win_set_cursor(term_win, {line_count, 0})
          end
        end,
      })
      
      vim.cmd('startinsert')
      vim.api.nvim_create_autocmd('TermClose', {
        buffer = term_buf,
        once = true,
        callback = function()
          local exit_code = vim.v.event.status
          if exit_code == 0 then
            -- Close terminal window on success
            if vim.api.nvim_win_is_valid(term_win) then
              vim.api.nvim_win_close(term_win, true)
            end
            onSuccess()
          else
            vim.notify('Build failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
          end
        end,
      })
    end
    
    if projectType == 'standalone' then
      -- ==== STANDALONE FLOW ====
      local function runStandaloneBuild(cfg)
        local cmd = script .. ' ' .. vim.fn.shellescape(root) .. ' ' .. cfg.buildScheme .. ' Standalone'
        runBuildInTerminal(cmd, function()
          vim.notify('Built! Launching Standalone...', vim.log.levels.INFO, { timeout = 1500 })
          
          -- Launch and attach using "Launch Standalone" DAP config
          vim.defer_fn(function()
            for _, dapCfg in ipairs(dap.configurations.cpp) do
              if dapCfg.name == 'Launch Standalone' then
                dap.run(dapCfg)
                return
              end
            end
            vim.notify('DAP config not found: Launch Standalone', vim.log.levels.ERROR)
          end, 1000)
        end)
      end
      
      -- Load standalone config (shows dialog if missing/invalid)
      local config = dapConfig.loadStandaloneConfig(function(cfg)
        if cfg then runStandaloneBuild(cfg) end
      end)
      
      -- If config already valid, run immediately
      if config then
        runStandaloneBuild(config)
      end
      
    elseif projectType == 'plugin' then
      -- ==== PLUGIN FLOW ====
      local function runBuild(cfg)
        local cmd = script .. ' ' .. vim.fn.shellescape(root) .. ' ' .. cfg.buildScheme .. ' ' .. cfg.format
        runBuildInTerminal(cmd, function()
          vim.notify('Built! Launching DAW...', vim.log.levels.INFO, { timeout = 1500 })
          vim.fn.jobstart({ cfg.dawPath })
          
          -- Run correct DAP config based on format
          local configName = dapConfig.getConfigNameForFormat(cfg.format)
          vim.defer_fn(function()
            for _, dapCfg in ipairs(dap.configurations.cpp) do
              if dapCfg.name == configName then
                dap.run(dapCfg)
                return
              end
            end
            vim.notify('DAP config not found: ' .. configName, vim.log.levels.ERROR)
          end, 2000)
        end)
      end

      -- Load plugin config (shows dialog if missing/invalid)
      local config = dapConfig.loadDawConfig(function(cfg)
        if cfg then runBuild(cfg) end
      end)
      
      -- If config already valid, run immediately
      if config then
        runBuild(config)
      end
      
    else
      -- ==== CANNOT DETECT ====
      vim.notify('Cannot detect project type. Check CMakeLists.txt or build directory.', vim.log.levels.ERROR)
    end
  end, { desc = 'DAP: Build and run' })

  vim.keymap.set('n', '<leader>bb', runBuildOnly, { desc = 'DAP: Build only' })

  vim.keymap.set('n', '<leader>bc', function()
    -- Clean + build: first run clean, then build on success
    local root = vim.fn.getcwd()
    local cleanScript = vim.fn.stdpath('config') .. '/scripts/clean-build.sh'
    
    if vim.fn.filereadable(cleanScript) ~= 1 then
      vim.notify('clean-build.sh not found in nvim config', vim.log.levels.ERROR)
      return
    end

    -- Close existing terminal
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == 'terminal' then
        vim.api.nvim_win_close(win, true)
        break
      end
    end

    -- Run clean, then build on success
    vim.cmd('botright 20split | terminal ' .. cleanScript .. ' ' .. root)
    local term_buf = vim.api.nvim_get_current_buf()
    
    vim.cmd('startinsert')
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = term_buf,
      once = true,
      callback = function()
        local exit_code = vim.v.event.status
        if exit_code == 0 then
          vim.notify('Clean succeeded, running build...', vim.log.levels.INFO)
          -- Call build function directly
          runBuildOnly()
        else
          vim.notify('Clean failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
        end
      end,
    })
  end, { desc = 'DAP: Clean build' })

  vim.keymap.set('n', '<leader>bk', runCleanOnly, { desc = 'DAP: Clean' })
end

-- Surround: use mini.surround defaults
-- sa{motion}{char} = add surround (e.g., saiw" surrounds word with ")
-- sd{char}         = delete surround
-- sr{old}{new}     = replace surround
function M.setupSurround()
end

-- Mini.pairs keymaps
function M.setupMiniPairs()
  -- Tab to jump out of brackets/quotes
  vim.keymap.set('i', '<Tab>', function()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local char = vim.api.nvim_get_current_line():sub(col + 1, col + 1)

    if char:match('[%)%]%}%"\'`]') then
      return '<Right>'
    else
      return '<Tab>'
    end
  end, { expr = true, noremap = true })

  -- Semicolon to jump out of () or {} and add ;
  vim.keymap.set('i', ';', function()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local char = vim.api.nvim_get_current_line():sub(col + 1, col + 1)

    if char == ')' or char == '}' then
      return '<Right>;'
    else
      return ';'
    end
  end, { expr = true, noremap = true })
end

-- Flash keymaps
function M.setupFlash()
  vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = 'Flash' })
  vim.keymap.set({ 'n', 'x', 'o' }, 'S', function() require('flash').treesitter() end, { desc = 'Flash Treesitter' })
  vim.keymap.set('o', 'r', function() require('flash').remote() end, { desc = 'Remote Flash' })
  vim.keymap.set({ 'o', 'x' }, 'R', function() require('flash').treesitter_search() end, { desc = 'Treesitter Search' })
  vim.keymap.set('c', '<c-s>', function() require('flash').toggle() end, { desc = 'Toggle Flash Search' })
end

return M