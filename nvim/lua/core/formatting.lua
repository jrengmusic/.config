-- Custom formatting logic for C/C++
local M = {}

-- Module-level so formatBuffer() can build the jobstart array
local clangFormatBin
local stylePath

function M.setup()
  vim.env.PATH = '/opt/homebrew/bin:/opt/local/bin:' .. vim.env.PATH

  if vim.fn.has('win32') == 1 then
    stylePath = 'C:\\Users\\jreng\\Documents\\Poems\\dev\\JUCE.clang-format'
    clangFormatBin = 'C:\\Program Files\\Microsoft Visual Studio\\18\\Community\\VC\\Tools\\Llvm\\x64\\bin\\clang-format.exe'
  else
    stylePath = '/Users/jreng/Documents/Poems/dev/JUCE.clang-format'
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

    -- Array form bypasses the shell entirely (no quoting issues with spaces
    -- in paths) and stdout_buffered hands on_stdout the fully-collected,
    -- already-line-split output in one call — identical async, non-blocking
    -- path on both platforms, no manual chunk-stitching needed.
    local output_lines = nil
    vim.fn.jobstart({ clangFormatBin, '--style=file:' .. stylePath, tmpfile }, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        output_lines = data
      end,
      on_exit = function(_, exit_code)
        if exit_code == 0 and output_lines and #output_lines > 0 then
          -- jobstart appends a trailing empty string; drop it
          if output_lines[#output_lines] == '' then
            table.remove(output_lines)
          end
          -- Strip embedded CR bytes (Windows pipe may produce CRLF)
          for i, line in ipairs(output_lines) do
            output_lines[i] = line:gsub('\r', '')
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
