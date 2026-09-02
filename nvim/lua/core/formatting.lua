-- Custom formatting logic for C/C++
local M = {}

local is_windows = vim.fn.has('win32') == 1

-- The one JUCE style, shipped with the config on every machine.
local STYLE_PATH = vim.fn.stdpath('config') .. '/clang-format/JUCE.clang-format'

-- Windows: the LLVM clang-format Visual Studio installs. macOS: the first
-- clang-format on PATH, then MacPorts' versioned name, then Homebrew's.
local CLANG_FORMAT_WINDOWS = 'C:\\Program Files\\Microsoft Visual Studio\\18\\Community\\VC\\Tools\\Llvm\\x64\\bin\\clang-format.exe'
local CLANG_FORMAT_CANDIDATES_MAC = { 'clang-format', 'clang-format-mp-21', '/opt/homebrew/bin/clang-format' }

local clangFormatBin

local function getClangFormat()
  if is_windows then return CLANG_FORMAT_WINDOWS end
  for _, candidate in ipairs(CLANG_FORMAT_CANDIDATES_MAC) do
    if vim.fn.executable(candidate) == 1 then return candidate end
  end
  return CLANG_FORMAT_CANDIDATES_MAC[1]
end

function M.setup()
  vim.env.PATH = '/opt/homebrew/bin:/opt/local/bin:' .. vim.env.PATH
  clangFormatBin = getClangFormat()
  vim.g.clang_format_command = clangFormatBin .. ' --style=file:' .. STYLE_PATH
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
    vim.fn.jobstart({ clangFormatBin, '--style=file:' .. STYLE_PATH, tmpfile }, {
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
