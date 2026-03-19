-- Custom formatting logic for C/C++
local M = {}

-- Module-level so formatBuffer() can build the jobstart array on Windows
local clangFormatBin
local stylePath

function M.setup()
  vim.env.PATH = '/opt/homebrew/bin:/opt/local/bin:' .. vim.env.PATH

  if vim.fn.has('win32') == 1 then
    stylePath = 'C:\\Users\\jreng\\Documents\\Poems\\kuassa\\___lib___\\JUCE.clang-format'
    clangFormatBin = 'C:\\Program Files\\Microsoft Visual Studio\\18\\Community\\VC\\Tools\\Llvm\\x64\\bin\\clang-format.exe'
  else
    stylePath = '/Users/jreng/Documents/Poems/kuassa/___lib___/JUCE.clang-format'
    clangFormatBin = 'clang-format'

    if vim.fn.executable('clang-format') == 1 then
      clangFormatBin = 'clang-format'
    elseif vim.fn.executable('clang-format-mp-21') == 1 then
      clangFormatBin = 'clang-format-mp-21'
    elseif vim.fn.executable('/opt/homebrew/bin/clang-format') == 1 then
      clangFormatBin = '/opt/homebrew/bin/clang-format'
    end
  end

  vim.g.clang_format_command = clangFormatBin .. ' --style=file:' .. stylePath
end

function M.formatBuffer()
  local filetype = vim.bo.filetype
  if filetype ~= 'cpp' and filetype ~= 'c' and filetype ~= 'objc' and filetype ~= 'objcpp' then
    return
  end

  vim.schedule(function()
    local tmpfile = vim.fn.tempname()
    vim.cmd('write! ' .. tmpfile)

    if vim.fn.has('win32') == 1 then
      -- On Windows: use jobstart with array form to bypass shell entirely (avoids zsh/bash issues)
      -- Each element is a separate arg — no shell, no quoting issues with spaces in paths
      local output_lines = {}
      vim.fn.jobstart({ clangFormatBin, '--style=file:' .. stylePath, tmpfile }, {
        on_stdout = function(_, data)
          for _, line in ipairs(data) do
            table.insert(output_lines, line)
          end
        end,
        on_exit = function(_, exit_code)
          if exit_code == 0 and #output_lines > 0 then
            -- jobstart appends a trailing empty string; drop it
            if output_lines[#output_lines] == '' then
              table.remove(output_lines)
            end
            if vim.bo.modifiable then
              vim.api.nvim_buf_set_lines(0, 0, -1, false, output_lines)
            end
          elseif exit_code ~= 0 then
            vim.notify('clang-format failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
          end
          os.remove(tmpfile)
        end,
      })
    else
      local formatted = vim.fn.system(vim.g.clang_format_command .. ' < ' .. tmpfile)
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
    end
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
