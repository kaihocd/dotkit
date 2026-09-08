local event = require('popup.instance.event')
local group = require('popup.instance.group')

local External = {}
External.__index = External

local function valid_win(win)
  return type(win) == 'number' and vim.api.nvim_win_is_valid(win)
end

function External.new(opts)
  assert(opts and valid_win(opts.win), 'popup.external requires a valid window')

  local self = setmetatable({
    win = opts.win,
    style = opts.style or {},
    geometry = opts.geometry,
    on_close_request = opts.on_close_request,
    closing = false,
    detached = false,
    _listeners = {},
    autocmds = {},
    _group = nil,
  }, External)

  self:apply()
  self.autocmds.win_closed = vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(self.win),
    once = true,
    callback = function()
      self:detach('window_closed')
    end,
  })

  if self.geometry then
    self.autocmds.resized = vim.api.nvim_create_autocmd('VimResized', {
      callback = function()
        self:apply()
      end,
    })
  end

  if opts.group then
    self:join_group(opts.group)
  end

  self:emit('open')
  return self
end

function External:is_open()
  return not self.detached and valid_win(self.win)
end

function External:apply()
  if not self:is_open() then
    return self
  end

  local config = {}
  if self.geometry then
    local geometry = self.geometry()
    for key, value in pairs(geometry) do
      config[key] = value
    end
    config.relative = config.relative or 'editor'
  end
  for key, value in pairs(self.style) do
    if key ~= 'winhl' then
      config[key] = value
    end
  end

  if next(config) then
    vim.api.nvim_win_set_config(self.win, config)
  end

  if self.style.winhl then
    vim.api.nvim_set_option_value('winhl', self.style.winhl, { scope = 'local', win = self.win })
  end

  return self
end

function External:on(name, callback)
  event.on(self, name, callback)
  return self
end

function External:emit(name, ...)
  event.emit(self, name, ...)
  return self
end

function External:join_group(name)
  group.join_group(self, name)
  return self
end

function External:leave_group()
  group.leave_group(self)
  return self
end

function External:hide()
  return self:close('group_hide')
end

function External:show()
  return self
end

function External:close(reason)
  if self.detached or self.closing then
    return self
  end

  self.closing = true
  if self.on_close_request then
    self.on_close_request(reason or 'close')
  end
  self.closing = false
  return self
end

function External:detach(reason)
  if self.detached then
    return self
  end

  self.detached = true
  for _, id in pairs(self.autocmds) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  self.autocmds = {}
  group.leave_group(self)
  self:emit('close', reason or 'detach')
  self._listeners = {}
  return self
end

return External
