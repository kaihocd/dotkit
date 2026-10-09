vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local Session = require('picker.picker.panel')
local blocked, requested = false, false
local grep = Session.new({
  search = function(_, _, _, offset)
    if blocked and offset == 0 then
      requested = true
      return { status = 'indexing', items = {}, total = 0 }
    end
    local items = {}
    for index = 1, 2 do
      items[index] = {
        path = '/retry-' .. offset,
        display = 'retry',
        line = offset * 2 + index,
        col = 0,
        content = 'hit',
      }
    end
    return {
      status = 'ready',
      items = items,
      total = 10,
      more = offset < 4,
      next_offset = offset + 1,
    }
  end,
}, function() end, nil, nil, true)
grep:open()
for _ = 1, 8 do
  grep:move(1)
end
blocked = true
for _ = 1, 7 do
  grep:move(-1)
end
assert(requested and grep.selection:current() == nil)
blocked = false
assert(vim.wait(2000, function()
  local entry = grep.selection:current()
  return entry ~= nil and entry.path == '/retry-0' and entry.line == 2
end))
grep:close()
vim.wait(100)
vim.o.lines = 30
local files = Session.new({
  search = function(_, size, _, page)
    if blocked then
      return { status = 'indexing', items = {}, total = 0 }
    end
    local items = {}
    for index = page * size + 1, (page + 1) * size do
      items[#items + 1] = { path = '/r-' .. index, display = 'r-' .. index }
    end
    return { status = 'ready', items = items, total = 1000 }
  end,
}, function() end)
files:open()
for _ = 1, files.window:page_size() + 3 do
  files:move(1)
end
local expected = files.selection:current().path
blocked = true
vim.o.lines = 40
vim.api.nvim_exec_autocmds('VimResized', {})
assert(files.selection:current() == nil)
blocked = false
assert(vim.wait(2000, function()
  local entry = files.selection:current()
  return entry ~= nil and entry.path == expected
end))
files:close()
vim.wait(100)
assert(#vim.api.nvim_list_wins() == 1)
print('PASS Session evicted grep page and files resize retain targets through indexing retries')
