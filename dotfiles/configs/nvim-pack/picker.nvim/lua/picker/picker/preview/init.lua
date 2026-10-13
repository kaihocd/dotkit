local Content = require('picker.picker.preview.content')

---@class picker.picker.PreviewDisplay
---@field visible fun(): boolean
---@field content fun(lines: string[], line: integer?, path: string?)
---@field matches fun(entry: picker.picker.Entry?)
---@field position fun(line: integer?)

---Owns preview delivery lifetime, while Window owns the pane and scratch buffer.
---@class picker.picker.Preview
---@field _content picker.picker.PreviewContent
---@field _revision integer
---@field _shown? {path: string, line: integer?, lines: string[], message: string?}
local Preview = {}
Preview.__index = Preview

---@param settings picker.PreviewConfig
---@return picker.picker.Preview
function Preview.new(settings)
  return setmetatable({ _content = Content.new(1024 * 1024, settings), _revision = 0 }, Preview)
end

---@param view picker.picker.PreviewDisplay
---@param entry? picker.picker.Entry
---@param run fun(operation: fun())
---@param nearby picker.picker.Entry[]
function Preview:update(view, entry, run, nearby)
  self._revision = self._revision + 1
  local revision = self._revision
  self._content:invalidate()
  if not view.visible() then
    return
  end
  if not entry then
    self._shown = nil
    view.content({ 'No Item' })
    return
  end
  local shown = self._shown
  local same_file = shown and shown.path == entry.path
  local loading = false
  local delivered = false
  if not same_file then
    -- Cache hits should never clear the pane or reload syntax through a message.
    view.matches(nil)
    vim.defer_fn(function()
      if revision ~= self._revision or delivered or not view.visible() then
        return
      end
      run(function()
        loading = true
        self._shown = nil
        view.content({ 'Loading…' })
      end)
    end, 80)
  end
  self._content:request(entry.path, function(lines, message)
    if revision ~= self._revision then
      return
    end
    delivered = true
    run(function()
      local content = lines or { message or 'Unable to read file' }
      if
        not loading
        and same_file
        and shown
        and shown.message == message
        and vim.deep_equal(shown.lines, content)
      then
        if shown.line ~= entry.line then
          view.position(lines and entry.line or nil)
          shown.line = entry.line
        end
        view.matches(lines and entry or nil)
        return
      end
      self._shown =
        { path = entry.path, line = entry.line, lines = vim.list_slice(content), message = message }
      view.content(content, lines and entry.line or nil, lines and entry.path or nil)
      view.matches(lines and entry or nil)
    end)
  end)
  local paths = {}
  for _, neighbor in ipairs(nearby) do
    if neighbor.path ~= entry.path then
      paths[#paths + 1] = neighbor.path
    end
  end
  self._content:prefetch(paths)
end

function Preview:close()
  self._revision = self._revision + 1
  self._content:close()
end

return Preview
