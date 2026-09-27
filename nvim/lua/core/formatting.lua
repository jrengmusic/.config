-- Buffer formatting: clang-format for C/C++, cast for markdown, conform for
-- every other filetype.
local M = {}

local is_windows = vim.fn.has('win32') == 1

local CAST_BINARY = require('core.project.cast').CAST_BINARY

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

-- Replaces the buffer with a formatter's stdout, as jobstart delivers it.
local function setBufferLines(output_lines)
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
end

function M.formatBuffer()
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
          setBufferLines(output_lines)
        elseif exit_code ~= 0 then
          vim.notify('clang-format failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
        end
        os.remove(tmpfile)
      end,
    })
  end)
end

-- The buffer text goes to cast on stdin. --assume-filename starts cast's
-- .cast-format search at the buffer's own directory, so every buffer gets
-- its project's style, inside or outside a cast project.
function M.formatMarkdown()
  vim.schedule(function()
    local output_lines = nil
    local error_lines = nil
    local job = vim.fn.jobstart({ CAST_BINARY, '--format', '--assume-filename=' .. vim.api.nvim_buf_get_name(0) }, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        output_lines = data
      end,
      on_stderr = function(_, data)
        error_lines = data
      end,
      on_exit = function(_, exit_code)
        if exit_code == 0 and output_lines and #output_lines > 0 then
          setBufferLines(output_lines)
        elseif exit_code ~= 0 then
          vim.notify(table.concat(error_lines, '\n'), vim.log.levels.ERROR)
        end
      end,
    })
    -- chansend joins list items with LF; the trailing '' gives the final LF.
    local input_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    table.insert(input_lines, '')
    vim.fn.chansend(job, input_lines)
    vim.fn.chanclose(job, 'stdin')
  end)
end

function M.formatWithConform()
  vim.schedule(function()
    require('conform').format({ async = true, lsp_format = 'fallback' })
  end)
end

local FORMATTERS = {
  c = M.formatBuffer,
  cpp = M.formatBuffer,
  objc = M.formatBuffer,
  objcpp = M.formatBuffer,
  markdown = M.formatMarkdown,
}

function M.formatBufferByFiletype()
  local format = FORMATTERS[vim.bo.filetype] or M.formatWithConform
  format()
end

return M
