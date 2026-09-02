-- core/markdown-table.lua
-- Generic markdown-table reader. Locates a table by the heading that
-- immediately precedes it (JAM's jam::MarkdownDocument::getTableId()
-- semantics: nearest preceding `#`/`##` heading, matched case-insensitively)
-- and parses both pipe tables and grid tables into { headers, rows }.
--
-- Cells are single-line only -- JAM's grid-table multi-line cell
-- accumulation (used by CAST's own .cast manifests) is out of scope: no
-- current consumer (KEYMAPS.md, project-info.md) has multi-line cells.
local M = {}

-- Splits a table row on unescaped pipes. A backslash immediately before a
-- pipe escapes it; an even run of backslashes (including zero) does not.
-- Mirrors jam_MarkdownBlockParser.cpp's splitTableRow() pipe-parity logic.
local function splitRow(line)
  local body = vim.trim(line):gsub('^|', ''):gsub('|$', '')
  local cells, cell, backslashes = {}, {}, 0

  for index = 1, #body do
    local char = body:sub(index, index)
    if char == '\\' then
      backslashes = backslashes + 1
      cell[#cell + 1] = char
    elseif char == '|' and backslashes % 2 == 0 then
      cells[#cells + 1] = vim.trim(table.concat(cell))
      cell, backslashes = {}, 0
    else
      backslashes = 0
      cell[#cell + 1] = char
    end
  end
  cells[#cells + 1] = vim.trim(table.concat(cell))

  return cells
end

local function isPipeAlignmentRow(cells)
  if #cells == 0 then return false end
  for _, cell in ipairs(cells) do
    if not cell:match('^:?%-+:?$') then return false end
  end
  return true
end

local function isGridBorder(line)
  return vim.trim(line):match('^%+[%-=+]+%+$') ~= nil
end

-- Parses a pipe table starting at `lines[index]` (the header row). Returns
-- the parsed table and the line index just past it, or nil if `index` is
-- not actually a pipe-table header (no valid alignment row follows).
local function parsePipeTable(lines, index)
  local alignmentLine = lines[index + 1]
  if not (alignmentLine and alignmentLine:match('^|')
          and isPipeAlignmentRow(splitRow(alignmentLine))) then
    return nil, index + 1
  end

  local headers = splitRow(lines[index])
  local rows, rowIndex = {}, index + 2

  while lines[rowIndex] and lines[rowIndex]:match('^|') do
    local row = splitRow(lines[rowIndex])
    row.line = rowIndex
    rows[#rows + 1] = row
    rowIndex = rowIndex + 1
  end

  return { headers = headers, rows = rows }, rowIndex
end

-- Parses a grid table whose top border is `lines[index]`. Returns the
-- parsed table and the line index just past it, or nil if no header row
-- follows the border.
local function parseGridTable(lines, index)
  local headerIndex = index + 1
  if not (lines[headerIndex] and lines[headerIndex]:match('^|')) then
    return nil, index + 1
  end

  local headers = splitRow(lines[headerIndex])
  local rowIndex = headerIndex + 1
  if lines[rowIndex] and isGridBorder(lines[rowIndex]) then
    rowIndex = rowIndex + 1
  end

  local rows = {}
  while lines[rowIndex] do
    local line = lines[rowIndex]
    if line:match('^|') then
      local row = splitRow(line)
      row.line = rowIndex
      rows[#rows + 1] = row
      rowIndex = rowIndex + 1
    elseif isGridBorder(line) then
      rowIndex = rowIndex + 1
      if not (lines[rowIndex] and lines[rowIndex]:match('^|')) then break end
    else
      break
    end
  end

  return { headers = headers, rows = rows }, rowIndex
end

-- Reads every table in `path`, each tagged with `heading` (the nearest
-- preceding `#`/`##` heading text, or '' if none) and `headingLine` (that
-- heading's source line number).
function M.getTables(path)
  local file = io.open(path, 'r')
  if not file then return nil end
  local text = file:read('*a')
  file:close()

  local lines = {}
  for line in (text .. '\n'):gmatch('(.-)\n') do lines[#lines + 1] = line end

  local tables = {}
  local heading, headingLine = '', 0
  local index = 1

  while index <= #lines do
    local headingText = lines[index]:match('^#+%s*(.-)%s*$')
    if headingText then
      heading, headingLine = headingText, index
      index = index + 1
    elseif isGridBorder(lines[index]) then
      local parsed, nextIndex = parseGridTable(lines, index)
      if parsed then
        parsed.heading, parsed.headingLine = heading, headingLine
        tables[#tables + 1] = parsed
      end
      index = nextIndex
    elseif lines[index]:match('^|') then
      local parsed, nextIndex = parsePipeTable(lines, index)
      if parsed then
        parsed.heading, parsed.headingLine = heading, headingLine
        tables[#tables + 1] = parsed
      end
      index = nextIndex
    else
      index = index + 1
    end
  end

  return tables
end

-- Returns `parsedTable`'s rows as records keyed by header text, each
-- carrying the row's source line under `line`.
function M.getRecords(parsedTable)
  local records = {}
  if not parsedTable then return records end

  for _, row in ipairs(parsedTable.rows) do
    local record = { line = row.line }
    for index, header in ipairs(parsedTable.headers) do
      record[header] = row[index]
    end
    records[#records + 1] = record
  end

  return records
end

-- Returns every value in `headerName`'s column across `parsedTable`'s rows.
function M.getColumn(parsedTable, headerName)
  local values = {}
  if not parsedTable then return values end

  local columnIndex
  for index, header in ipairs(parsedTable.headers) do
    if header == headerName then columnIndex = index end
  end
  if not columnIndex then return values end

  for _, row in ipairs(parsedTable.rows) do
    values[#values + 1] = row[columnIndex]
  end

  return values
end

return M
