local M = {}

---@class picker.picker.TextHighlight
---@field first integer
---@field last integer
---@field group string
---@field priority integer

---Keep path segments and their byte offsets together when moving the basename first.
---@param entry picker.picker.Entry
---@param icon? string
---@param icon_highlight? string
---@return string
---@return picker.picker.TextHighlight[]
function M.file(entry, icon, icon_highlight, match)
  local path = entry.display:gsub('[\r\n\t]', ' ')
  local separator = path:match('^.*()/') or 0
  local name = path:sub(separator + 1)
  local directory = separator > 0 and path:sub(1, separator - 1) or ''
  local prefix = icon and icon ~= '' and (icon .. '  ') or ''
  local text = prefix .. name
  local directory_col = #text + 1

  if directory ~= '' then
    text = text .. ' ' .. directory
  end

  local highlights = {}
  local function add(first, last, group, priority)
    if group and last > first then
      highlights[#highlights + 1] =
        { first = first, last = last, group = group, priority = priority }
    end
  end

  if icon then
    add(0, #icon, icon_highlight, 100)
  end
  add(directory_col, directory_col + #directory, 'Comment', 100)

  -- fff ranges are half-open byte offsets into the original relative path.
  local segments = { { separator, #path, #prefix }, { 0, #directory, directory_col } }
  for _, range in ipairs(entry.match_ranges or {}) do
    for _, segment in ipairs(segments) do
      local first, last = math.max(range[1], segment[1]), math.min(range[2], segment[2])
      if first < last then
        add(segment[3] + first - segment[1], segment[3] + last - segment[1], match or 'Search', 200)
      end
    end
  end

  return text, highlights
end

---@param entry picker.picker.Entry
---@return string
---@return picker.picker.TextHighlight[]
function M.match(entry, match)
  local location = ':' .. (entry.line or 1) .. ':' .. ((entry.col or 0) + 1)
  local prefix = location .. '  '
  local content = (entry.content or ''):gsub('[\r\n\t]', ' ')

  local highlights = { { first = 0, last = #location, group = 'Comment', priority = 100 } }
  for _, highlight in ipairs(require('picker.picker.window.syntax').highlights(entry.path, content)) do
    highlights[#highlights + 1] = {
      first = #prefix + highlight.first,
      last = #prefix + highlight.last,
      group = highlight.group,
      priority = highlight.priority,
    }
  end

  for _, range in ipairs(entry.content_matches or {}) do
    local first, last = math.max(0, range[1]), math.min(#content, range[2])
    if last > first then
      highlights[#highlights + 1] = {
        first = #prefix + first,
        last = #prefix + last,
        group = match or 'Search',
        priority = 200,
      }
    end
  end

  return prefix .. content, highlights
end

return M
