-- DAP configuration
return {
  lazy = true,
  keys = {
    { '<leader>dc', desc = 'DAP: Continue' },
    { '<leader>db', desc = 'DAP: Toggle breakpoint' },
    { '<leader>br', desc = 'Build and run' },
    { '<leader>bb', desc = 'Build only' },
    { '<leader>bc', desc = 'Clean build' },
    { '<leader>bk', desc = 'Clean' },
    { '<F5>', desc = 'Configure project' },
  },
  cmd = { 'DapContinue', 'DapToggleBreakpoint' },
  deps = 'dap',
  setup = function()
    -- Ensure mason-nvim-dap is set up once (installs codelldb if missing)
    local ok, mason_dap = pcall(require, 'mason-nvim-dap')
    if ok then
      mason_dap.setup({ ensure_installed = { 'codelldb' }, automatic_installation = true })
    end

    -- macOS: re-sign codelldb with debugger entitlement after every Mason install.
    -- Mason-installed codelldb is ad-hoc signed with no entitlements; SIP blocks
    -- it from attaching to / launching processes without com.apple.security.cs.debugger.
    if vim.fn.has('mac') == 1 then
      local registry_ok, registry = pcall(require, 'mason-registry')
      if registry_ok then
        local function sign_codelldb()
          local codelldb_path = vim.fn.stdpath('data')
            .. '/mason/packages/codelldb/extension/adapter/codelldb'
          if vim.fn.executable(codelldb_path) ~= 1 then return end
          -- Check if already signed with the debugger entitlement
          local check = vim.fn.system(
            'codesign -d --entitlements - ' .. vim.fn.shellescape(codelldb_path) .. ' 2>&1'
          )
          if check:find('cs.debugger') then return end  -- already good
          local entitlements = [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.cs.debugger</key><true/>
  <key>com.apple.security.cs.allow-jit</key><true/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
  <key>com.apple.security.cs.disable-library-validation</key><true/>
</dict></plist>]]
          local tmpfile = os.tmpname() .. '.xml'
          local f = io.open(tmpfile, 'w')
          if not f then return end
          f:write(entitlements)
          f:close()
          vim.fn.system(
            'codesign --force --sign - --entitlements '
              .. vim.fn.shellescape(tmpfile)
              .. ' '
              .. vim.fn.shellescape(codelldb_path)
          )
          os.remove(tmpfile)
          vim.notify('codelldb: re-signed with debugger entitlement', vim.log.levels.INFO)
        end

        -- Run on install/upgrade of codelldb
        registry:on('package:install:success', function(pkg)
          if pkg.name == 'codelldb' then
            vim.schedule(sign_codelldb)
          end
        end)

        -- Run now in case it lost its signature (e.g. first launch after Mason update)
        vim.schedule(sign_codelldb)
      end
    end

    local adaptersOk = require('dap.adapters').setup()
    if not adaptersOk then
      return
    end

    require('dap.configurations').setup()
    require('dap.dapui_config').setup()
  end,
}
