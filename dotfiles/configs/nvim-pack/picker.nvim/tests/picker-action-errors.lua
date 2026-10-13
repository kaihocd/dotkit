vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local Session = require('picker.picker.panel')
local messages = {}
local function notify(text)
  messages[#messages + 1] = text
end
vim.notify = notify
for _, case in ipairs({
  { 'move', 0 / 0, 'finite integer' },
  { 'move', math.huge, 'finite integer' },
  { 'move', 1.5, 'finite integer' },
  { 'mark', 2, '-1, 0 or 1' },
  { 'page', 0, '-1 or 1' },
  { 'page', 2, '-1 or 1' },
  { 'scroll_preview', -math.huge, 'finite integer' },
}) do
  local calls, completions = 0, 0
  local session = Session.new(
    {
      search = function()
        calls = calls + 1
        return { status = 'ready', total = 1, items = { { path = '/a', display = 'a' } } }
      end,
    },
    function()
      completions = completions + 1
    end,
    nil,
    {
      i = {
        ['<F5>'] = function(actions)
          actions[case[1]](case[2])
        end,
      },
    }
  )
  session:open()
  local before = calls
  vim.fn.maparg('<F5>', 'i', false, true).callback()
  assert(vim.wait(2000, function()
    return completions == 1
  end))
  assert(messages[#messages]:find(case[3], 1, true))
  assert(calls == before and session.selection:marked_count() == 0)
  assert(#vim.api.nvim_list_wins() == 1)
end
print('PASS invalid action numbers fail before search/marks and release the session once')
