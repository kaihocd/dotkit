-- Content segments are the public display protocol; byte ranges stay internal.
local M = {}

---@param row picker.list.Row
---@return string
---@return table[]
function M.project(row)
  if type(row) ~= 'table' or type(row.content) ~= 'table' or not vim.islist(row.content) then
    error('picker: row.content must be an array', 0)
  end
  local parts, ranges, offset = {}, {}, 0
  for _, segment in ipairs(row.content) do
    if
      type(segment) ~= 'table'
      or type(segment[1]) ~= 'string'
      or (segment[2] ~= nil and type(segment[2]) ~= 'string')
    then
      error('picker: content segment must be { text, highlight? }', 0)
    end
    for key in pairs(segment) do
      if key ~= 1 and key ~= 2 then
        error('picker: unsupported content segment field', 0)
      end
    end
    local text = segment[1]:gsub('[\r\n\t]', ' ')
    parts[#parts + 1] = text
    if segment[2] and #text > 0 then
      ranges[#ranges + 1] =
        { first = offset, last = offset + #text, group = segment[2], priority = 200 }
    end
    offset = offset + #text
  end
  return table.concat(parts), ranges
end

---Convert overlapping internal syntax/match ranges into nonoverlapping segments.
---@param text string
---@param ranges table[]
---@return picker.list.Row
function M.from_ranges(text, ranges)
  local boundaries = { [0] = true, [#text] = true }
  for _, range in ipairs(ranges) do
    boundaries[math.max(0, math.min(#text, range.first))] = true
    boundaries[math.max(0, math.min(#text, range.last))] = true
  end
  local points = vim.tbl_keys(boundaries)
  table.sort(points)
  local content = {}
  for i = 1, #points - 1 do
    local first, last = points[i], points[i + 1]
    local group, priority = nil, -1
    for _, range in ipairs(ranges) do
      if range.first <= first and range.last >= last and range.priority >= priority then
        group, priority = range.group, range.priority
      end
    end
    content[#content + 1] = { text:sub(first + 1, last), group }
  end
  return { content = content }
end

return M
