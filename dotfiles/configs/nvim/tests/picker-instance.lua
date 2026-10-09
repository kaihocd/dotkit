local api = vim.api
local Instance = require('plugins.explorer.picker.instance')
local config = vim.deepcopy(require('plugins.explorer.picker.config'))
config.view.preview.enabled = false
local origin = api.nvim_get_current_win()
local baseline = #api.nvim_list_wins()
local searches, constructions = 0, 0
package.loaded['plugins.explorer.picker.search.files'] = {
  new = function()
    constructions = constructions + 1
    return {
      search = function()
        searches = searches + 1
        return { status = 'ready', items = {}, total = 0 }
      end,
    }
  end,
}
local closed = 0
local function new()
  return Instance.new({
    config = config,
    origin = origin,
    directory = vim.fn.getcwd(),
    current_file = '',
    title = 'Files',
    on_closed = function(instance)
      assert(instance.state == 'closed')
      assert(#api.nvim_list_wins() == baseline)
      closed = closed + 1
    end,
  })
end
local instance = new()
assert(instance.state == 'idle' and constructions == 0)
assert(#api.nvim_list_wins() == baseline, 'Construction must not allocate windows')
instance:start()
assert(instance.state == 'running' and constructions == 1)
instance:start()
assert(constructions == 1, 'Start must not duplicate resources')
local query = instance.view.query.buf
local navigate = vim.fn.maparg('<C-n>', 'i', false, true).callback
api.nvim_buf_set_lines(query, 0, -1, false, { 'pending query' })
api.nvim_exec_autocmds('TextChangedI', { buffer = query })
local count = searches
instance:close()
assert(instance.state == 'closing' and closed == 0)
instance:close()
navigate()
assert(vim.wait(1000, function()
  return instance.state == 'closed'
end))
navigate()
vim.wait(config.search.debounce_ms + 20)
assert(closed == 1 and searches == count, 'Close must reject queued work and stale bindings')
assert(not api.nvim_buf_is_valid(query))
instance:start()
assert(constructions == 1, 'Closed instances cannot restart')

local idle = new()
idle:close()
assert(vim.wait(1000, function()
  return idle.state == 'closed'
end))
assert(closed == 2 and constructions == 1)

-- Failure after View allocation must release the resources already acquired.
local list = require('plugins.explorer.picker.list')
local original_new, original_notify = list.new, vim.notify
local message
list.new = function()
  error('construction failed')
end
local function capture_notification(err)
  message = err
end
vim.notify = capture_notification
local failed = new()
failed:start()
assert(failed.state == 'closing')
assert(vim.wait(1000, function()
  return failed.state == 'closed'
end))
assert(closed == 3 and message:find('construction failed', 1, true))
list.new, vim.notify = original_new, original_notify
print('PASS explicit Picker instance lifecycle')
