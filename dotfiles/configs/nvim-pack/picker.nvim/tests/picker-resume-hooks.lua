vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local creates = 0
package.loaded['picker.picker.backend.fff'] = {
  files = function()
    creates = creates + 1
    return {
      search = function()
        return { status = 'ready', total = 0, items = {} }
      end,
    }
  end,
}
local notice
local function notify(message)
  notice = message
end
vim.notify = notify
require('picker').setup()
local picker = require('picker')
local a, b = 0, 0
local function first(instance)
  assert(not instance:is_open())
  a = a + 1
end
local function second(instance)
  assert(not instance:is_open())
  b = b + 1
end
local function close()
  vim.fn.maparg('<Esc>', 'i', false, true).callback()
  assert(vim.wait(1000, function()
    return #vim.api.nvim_list_wins() == 1
  end))
end
picker.resume({ on_instance = second })
assert(b == 0 and creates == 0)
local options = { on_instance = first }
picker.open(options)
assert(a == 1 and options.on_instance == first)
close()
picker.resume({ on_instance = second })
assert(a == 1 and b == 1)
close()
picker.resume()
assert(a == 1 and b == 1)
close()
picker.resume({
  on_instance = function()
    error('hook failed')
  end,
})
assert(notice:find('hook failed', 1, true))
assert(#vim.api.nvim_list_wins() == 1)
picker.resume({ on_instance = second })
assert(a == 1 and b == 2)
close()
local before = creates
picker.resume(vim.json.decode('{"on_instance":false}'))
assert(creates == before and notice:find('on_instance must be a function', 1, true))
print('PASS resume hooks are invocation-only, pre-open, preserve callers and allow failure retry')
