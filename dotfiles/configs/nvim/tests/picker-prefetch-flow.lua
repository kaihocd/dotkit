local requests = 0
package.loaded['plugins.explorer.picker.search.files'] = {
  new = function()
    return {
      search = function()
        return {
          status = 'ready',
          total = 3,
          items = {
            { path = '/a', display = 'a' },
            { path = '/b', display = 'b' },
            { path = '/c', display = 'c' },
          },
        }
      end,
    }
  end,
}
package.loaded['plugins.explorer.picker.preview'] = {
  new = function(_, content)
    return {
      show = function() end,
      prefetch = function()
        requests = requests + 1
      end,
      scroll = function() end,
      close = content.close,
    }
  end,
}
require('plugins.explorer.picker').open({ get_icon = function() end })
vim.wait(30)
local count = requests
local function key(k)
  vim.fn.maparg(k, 'i', false, true).callback()
end
key('<C-n>')
key('<C-n>')
vim.wait(30)
assert(requests == count + 1, 'Movement must coalesce nearby prefetch')
key('<C-o>')
vim.wait(30)
assert(requests == count + 2, 'Toggle must refresh current preview work')
key('<Esc>')
vim.wait(30)
print('PASS current-item prefetch flow')
