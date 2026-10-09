vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local creates = 0
local source_status = 'ready'
local empty = false
package.loaded['picker.picker.backend.fff'] = {
  files = function(cwd)
    assert(cwd == vim.uv.fs_realpath(vim.fn.getcwd()))
    creates = creates + 1
    return {
      search = function()
        return {
          status = source_status,
          total = empty and 0 or 1,
          items = empty and {} or { { path = '/a', display = 'a' } },
        }
      end,
    }
  end,
}
local notice
local function notify(text)
  notice = text
end
vim.notify = notify
local picker = require('picker')
picker.resume()
assert(notice == 'picker: no previous session' and creates == 0)
local configured = {
  prefix = { text = 'Find ', highlight = 'Title' },
  marker = { text = '*', highlight = 'Title' },
  messages = { empty = 'Nothing', indexing = 'Scanning files' },
  format = function(entry)
    return { content = { { 'custom:' .. entry.display } } }
  end,
}
picker.open({ view = { icon = false, presentation = configured } })
vim.fn.maparg('<Tab>', 'i', false, true).callback()
configured.marker.text = '!'
configured.messages.empty = 'Changed empty'
configured.messages.indexing = 'Changed indexing'
configured.prefix.text = 'Changed '
configured.format = function()
  return { content = { { 'changed' } } }
end
local input = vim.api.nvim_get_current_buf()
local query = 'latest中文'
vim.api.nvim_buf_set_lines(input, 0, -1, false, { query })
vim.fn.maparg('<Esc>', 'i', false, true).callback()
assert(vim.wait(2000, function()
  return #vim.api.nvim_list_wins() == 1
end))
for count = 2, 3 do
  picker.resume()
  assert(creates == count)
  assert(vim.api.nvim_get_current_buf() ~= input)
  assert(vim.api.nvim_get_current_line() == query)
  local prefixes = vim.api.nvim_buf_get_extmarks(
    0,
    vim.api.nvim_get_namespaces().PickerInput,
    0,
    -1,
    { details = true }
  )
  assert(prefixes[1][4].virt_text[2][1] == 'Find ')
  local found = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]:find('custom:a', 1, true) then
      found = true
    end
  end
  assert(found, 'resume must retain the copied formatter option')
  local marked = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local marks = vim.api.nvim_buf_get_extmarks(
      buf,
      vim.api.nvim_get_namespaces().PickerMarks,
      0,
      -1,
      { details = true }
    )
    for _, mark in ipairs(marks) do
      for _, chunk in ipairs(mark[4].virt_text or {}) do
        marked = marked or chunk[1] == '*'
      end
    end
  end
  assert(marked, 'resume must paint the copied marker for restored marks')
  assert(
    vim.api.nvim_win_get_cursor(0)[2] >= #query - 3,
    'resume must position the cursor at the final UTF-8 character'
  )
  vim.fn.maparg('<Esc>', 'i', false, true).callback()
  assert(vim.wait(2000, function()
    return #vim.api.nvim_list_wins() == 1
  end))
end
local function has_text(expected)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      if line:find(expected, 1, true) then
        return true
      end
    end
  end
  return false
end

empty = true
picker.resume()
assert(has_text('Nothing'), 'resume must paint the copied empty message')
vim.fn.maparg('<Esc>', 'i', false, true).callback()
assert(vim.wait(2000, function()
  return #vim.api.nvim_list_wins() == 1
end))

source_status = 'indexing'
picker.resume()
assert(has_text('Scanning files'), 'resume must paint the copied indexing message')
vim.fn.maparg('<Esc>', 'i', false, true).callback()
assert(vim.wait(2000, function()
  return #vim.api.nvim_list_wins() == 1
end))
source_status = 'ready'
empty = false

local group = require('popup').group('picker-resume-replacement', {
  on_join = function(instance, members)
    instance:on('open', function()
      for _, other in ipairs(vim.list_extend({}, members.instances)) do
        if other ~= instance and other:is_open() then
          other:close()
        end
      end
    end)
  end,
})
picker.open({
  on_instance = function(instance)
    instance:join_group(group.name)
  end,
})
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'old group query' })
picker.open({
  on_instance = function(instance)
    instance:join_group(group.name)
  end,
})
local replacement = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(replacement, 0, -1, false, { 'new group query' })
vim.wait(100)
assert(vim.api.nvim_get_current_buf() == replacement and #group.instances == 1)
-- Group membership is invocation-only: explicitly join when replacing the active UI.
picker.resume({
  on_instance = function(instance)
    instance:join_group(group.name)
  end,
})
assert(vim.api.nvim_get_current_line() == 'old group query')
vim.wait(100)
assert(#group.instances == 1)
vim.fn.maparg('<Esc>', 'i', false, true).callback()
assert(vim.wait(2000, function()
  return #vim.api.nvim_list_wins() == 1
end))
picker.resume()
assert(vim.api.nvim_get_current_line() == 'old group query')
vim.fn.maparg('<Esc>', 'i', false, true).callback()
assert(vim.wait(2000, function()
  return #vim.api.nvim_list_wins() == 1
end))
assert(#group.instances == 0)
print(
  'PASS public resume fresh sources, repeated restoration and group replacement snapshot ownership'
)
