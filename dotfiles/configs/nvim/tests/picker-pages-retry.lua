local model = require('plugins.explorer.picker.search')
local indexing = false
local pages = model.new({
  search = function()
    if indexing then
      return { status = 'indexing', items = {}, total = 0 }
    end
    return { status = 'ready', items = { {}, {}, {} }, total = 30 }
  end,
}, false)
pages.refresh('q', nil, 3)
assert(pages.move(3, 2))
indexing = true
local result, target = pages.refresh('q', nil, 3, true)
assert(result.status == 'indexing' and target == nil)
indexing = false
result, target = pages.refresh('q', nil, 3)
assert(target == 2, 'Retry must deliver the pending selection with ready results')
local _, consumed = pages.refresh('q', nil, 3, true)
assert(consumed == nil, 'Selection is delivered only once')
print('PASS pagination retry selection')
