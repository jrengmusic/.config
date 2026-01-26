-- Custom formatting logic for C/C++
local M = {}

function M.setup()
  vim.env.PATH = '/opt/homebrew/bin:/opt/local/bin:' .. vim.env.PATH

  local stylePath = '/Users/jreng/Documents/Poems/kuassa/___lib___/JUCE.clang-format'
  local clangFormatBin = 'clang-format'

  if vim.fn.executable('clang-format') == 1 then
    clangFormatBin = 'clang-format'
  elseif vim.fn.executable('clang-format-mp-21') == 1 then
    clangFormatBin = 'clang-format-mp-21'
  elseif vim.fn.executable('/opt/homebrew/bin/clang-format') == 1 then
    clangFormatBin = '/opt/homebrew/bin/clang-format'
  end

  vim.g.clang_format_command = clangFormatBin .. ' --style=file:' .. stylePath
end

function M.formatBuffer()
  local filetype = vim.bo.filetype
  if filetype ~= 'cpp' and filetype ~= 'c' and filetype ~= 'objc' and filetype ~= 'objcpp' then
    return
  end

  vim.schedule(function()
    local command = vim.g.clang_format_command
    local tmpfile = vim.fn.tempname()
    vim.cmd('write! ' .. tmpfile)
    local formatted = vim.fn.system(command .. ' < ' .. tmpfile)
    local exitCode = vim.v.shell_error

    if exitCode == 0 and formatted ~= '' then
      -- Check if buffer is modifiable before trying to format
      if vim.bo.modifiable then
        vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.split(formatted, '\n'))
      end
    elseif exitCode ~= 0 then
      vim.notify('clang-format failed (exit ' .. exitCode .. '): ' .. formatted, vim.log.levels.ERROR)
    end

    os.remove(tmpfile)
  end)
end

function M.formatWithConform()
  local filetype = vim.bo.filetype
  if filetype == 'cpp' or filetype == 'c' or filetype == 'objc' or filetype == 'objcpp' then
    return
  end

  vim.schedule(function()
    require('conform').format({ async = true, lsp_format = 'fallback' })
  end)
end

return M
