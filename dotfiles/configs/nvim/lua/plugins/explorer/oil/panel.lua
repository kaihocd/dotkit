local api = vim.api
local Preview = require('plugins.explorer.oil.preview')
local Panel = {}
Panel.__index = Panel

function Panel.new(config, on_closed)
  local self = setmetatable({
    config = config,
    phase = 'opening',
    origin = api.nvim_get_current_win(),
    on_closed = on_closed,
  }, Panel)
  local title =
    config.oil_title(require('oil').get_current_dir() or vim.fn.expand('%:p:h'), vim.fn.getcwd())
  self.popup = self:create_popup('oil', api.nvim_get_current_buf(), title)
  self.preview = Preview.new(function(buf)
    return self:create_popup('preview', buf, config.preview_title())
  end, function()
    if self:is_open() then
      self:render()
    end
  end)
  return self
end

function Panel:is_open()
  return self.phase == 'open'
end

function Panel:owns_window(win)
  return self:is_open() and self.win == win
end

function Panel:restore_origin()
  if vim.fn.getcmdwintype() == '' and api.nvim_win_is_valid(self.origin) then
    api.nvim_set_current_win(self.origin)
  end
end

-- Shared window setup. Keymaps are buffer-local and are not restored.
function Panel:create_popup(id, buf, title_opts)
  local popup = require('popup')
  local pane_spec = popup.pane({
    id = id,
    buf = buf,
    enter = id == 'oil',
    border = self.config.border,
    win_config = title_opts,
  })

  local instance = popup.root({
    row = 0,
    col = 0,
    width = self.config.min_pane_size,
    height = self.config.min_pane_size,
    layout = pane_spec,
  })

  instance:use(require('popup.extensions').keymap(vim.deepcopy(self.config.keymaps)))

  local options = id == 'oil' and self.config.oil_win_options or self.config.preview_win_options
  local function apply()
    local pane = instance:pane(id)
    if pane and api.nvim_win_is_valid(pane.win) then
      for option, value in pairs(options) do
        vim.wo[pane.win][option] = value
      end
    end
  end

  instance:on('open', apply):on('render', apply)
  return instance
end

-- Use the origin cwd and persist the title across renders.
function Panel:update_title()
  if not self.win or not api.nvim_win_is_valid(self.win) then
    return
  end

  local dir = require('oil').get_current_dir(api.nvim_win_get_buf(self.win))
  if not dir then
    return
  end

  local cwd = vim.fn.getcwd()
  if api.nvim_win_is_valid(self.origin) then
    cwd = api.nvim_win_call(self.origin, function()
      return vim.fn.getcwd()
    end)
  end

  local title_opts = self.config.oil_title(dir, cwd)
  self.popup:update(function(node)
    node.layout.win_config = title_opts
  end)

  api.nvim_win_set_config(self.win, title_opts)
end

-- Preview existing local files; show blank for other entries.
local function preview_path()
  local oil = require('oil')
  local entry, dir = oil.get_cursor_entry(), oil.get_current_dir()
  if not dir or not entry or not entry.id or entry.type ~= 'file' then
    return nil
  end

  local path = vim.fs.joinpath(dir, entry.name)
  if vim.fn.filereadable(path) == 1 then
    return path
  end
end

function Panel:select(opts)
  opts = opts or {}

  local selection = vim.tbl_extend('force', opts, {
    -- Let Oil resolve and save; keep directories here, open files outside.
    vertical = false,
    horizontal = false,
    split = nil,
    tab = false,
    handle_buffer_callback = function(buf)
      if not self:is_open() then
        return
      end
      if vim.startswith(api.nvim_buf_get_name(buf), 'oil://') then
        if api.nvim_win_is_valid(self.win) then
          api.nvim_win_set_buf(self.win, buf)
        end
        return
      end

      self:close()
      self:restore_origin()

      if opts.tab then
        vim.cmd.tabnew()
      elseif opts.vertical then
        vim.cmd.vsplit()
      elseif opts.horizontal then
        vim.cmd.split()
      end
      api.nvim_win_set_buf(0, buf)
    end,
  })

  require('oil').select(selection)
end

function Panel:render()
  if not self:is_open() then
    return
  end
  local area = self.config.geometry()
  if area.width < self.config.min_pane_size * 2 then
    self.preview:hide()
  end
  local left = self.preview:is_visible() and math.floor(area.width / 2) or area.width
  self.popup:set_pane_buf('oil', api.nvim_win_get_buf(self.win))
  self.popup:update(function(node)
    node.row, node.col = area.row, area.col
    node.width, node.height = left, area.height
  end)
  self.popup:render()
  self.preview:render({
    row = area.row,
    col = area.col + left,
    width = area.width - left,
    height = area.height,
  })
end

function Panel:update_preview()
  if self.preview:is_visible() and self:owns_window(api.nvim_get_current_win()) then
    self.preview:show(preview_path())
  end
end

function Panel:toggle_preview()
  local ok, err = xpcall(function()
    if self.preview:is_visible() then
      self.preview:hide()
    else
      if self.config.geometry().width < self.config.min_pane_size * 2 then
        vim.notify('Window too narrow for Oil preview', vim.log.levels.WARN)
        return
      end
      self.preview:open()
    end
    self:render()
    self:update_preview()
  end, debug.traceback)
  if not ok then
    self:close()
    error(err, 0)
  end
end

function Panel:scroll_preview(direction)
  self.preview:scroll(direction)
end

function Panel:bind_events()
  self.augroup = api.nvim_create_augroup('DotkitOilSession', { clear = true })
  self.popup:on('close', function()
    self:finish(true)
  end)
  api.nvim_create_autocmd('VimResized', {
    group = self.augroup,
    callback = function()
      self:refresh(false, true)
    end,
  })
  api.nvim_create_autocmd({ 'CursorMoved', 'BufEnter', 'DirChanged' }, {
    group = self.augroup,
    callback = function(event)
      vim.schedule(function()
        self:refresh(event.event ~= 'CursorMoved')
      end)
    end,
  })
end

-- Event failures terminate the panel instead of leaving half-updated resources.
function Panel:refresh(title, resize)
  if not self:is_open() then
    return
  end
  local ok, err = xpcall(function()
    if resize then
      self:render()
    end
    if title then
      self:update_title()
    end
    self:update_preview()
  end, debug.traceback)
  if not ok then
    self:close()
    vim.notify('Oil update: ' .. err, vim.log.levels.ERROR)
  end
end

function Panel:stop_events()
  local group = self.augroup
  self.augroup = nil
  if group then
    api.nvim_del_augroup_by_id(group)
  end
end

-- A Popup close event reports completed unmounting; do not close it again.
-- Failed opening instead uses close(), which also releases a partial mount.
function Panel:finish(popup_closed)
  if self.phase == 'closing' or self.phase == 'closed' then
    return
  end
  self.phase = 'closing'
  local errors = {}
  local function release(stage, fn)
    local ok, err = pcall(fn)
    if not ok then
      errors[#errors + 1] = '[' .. stage .. ']: ' .. tostring(err)
    end
  end
  release('events', function()
    self:stop_events()
  end)
  release('preview', function()
    self.preview:close()
  end)
  release('group', function()
    self.popup:leave_group()
  end)
  if not popup_closed then
    release('popup', function()
      self.popup:close()
    end)
  end
  self.phase = 'closed'
  release('owner', function()
    self.on_closed(self)
  end)
  if #errors > 0 then
    vim.notify('Oil cleanup ' .. table.concat(errors, '\n'), vim.log.levels.ERROR)
  end
end

function Panel:close()
  self:finish(false)
end

function Panel:open()
  assert(self.phase == 'opening', 'Oil panel can only be opened once')
  local ok, err = xpcall(function()
    local area = self.config.geometry()
    self.popup:update(function(node)
      node.row, node.col = area.row, area.col
      node.width, node.height = area.width, area.height
    end)
    self:bind_events()
    self.popup:join_group(self.config.group)
    self.popup:open()
    self.win = assert(self.popup:pane('oil'), 'Oil pane was not created').win
    self.phase = 'open'
    require('oil').open(nil, {}, function()
      self:refresh(true)
    end)
  end, debug.traceback)
  if not ok then
    self:close()
    error(err, 0)
  end
end

return Panel
