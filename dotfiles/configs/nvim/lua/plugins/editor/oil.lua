local M = {}
local active
local api = vim.api

local function enable_numbers(instance, id)
  local function apply()
    local pane = instance:pane(id)
    if pane and api.nvim_win_is_valid(pane.win) then
      vim.wo[pane.win].number = true
    end
  end
  instance:on('open', apply):on('render', apply)
end

local function geometry(node)
  node.width = math.max(3, math.floor(vim.o.columns * 0.7))
  node.height = math.max(3, math.floor(vim.o.lines * 0.8))
  node.row = math.floor((vim.o.lines - node.height) / 2)
  node.col = math.floor((vim.o.columns - node.width) / 2)
end

function M.close()
  if vim.bo.filetype == 'oil' and (not active or api.nvim_get_current_win() ~= active.win) then
    return require('oil').close()
  end
  if active then
    local session = active
    session.popup:close()
    if api.nvim_win_is_valid(session.origin) then
      api.nvim_set_current_win(session.origin)
    end
  end
end

function M.select(opts)
  opts = opts or {}
  local session = active
  if not session or api.nvim_get_current_win() ~= session.win then
    return require('oil').select(opts)
  end
  local selection = vim.tbl_extend('force', opts, {
    -- Perform destination-window selection after Oil resolves paths and saves edits.
    vertical = false, horizontal = false, split = nil, tab = false,
    handle_buffer_callback = function(buf)
      if vim.startswith(api.nvim_buf_get_name(buf), 'oil://') then
        if api.nvim_win_is_valid(session.win) then
          api.nvim_win_set_buf(session.win, buf)
        end
        return
      end
      if active == session then M.close() end
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

local function render(session)
  if not api.nvim_win_is_valid(session.win) then return end
  local area = {}
  geometry(area)
  if session.preview and area.width < 6 then
    local preview = session.preview
    session.preview = nil
    preview:close()
  end
  local left = session.preview and math.floor(area.width / 2) or area.width
  session.popup:set_pane_buf('oil', api.nvim_win_get_buf(session.win))
  session.popup:update(function(node)
    geometry(node)
    node.width = left
  end):render()
  if session.preview then
    session.preview:update(function(node)
      geometry(node)
      node.col = area.col + left
      node.width = area.width - left
    end):render()
  end
end

local function update_preview(session)
  if not session.preview or api.nvim_get_current_win() ~= session.win then return end
  local oil = require('oil')
  local entry, dir = oil.get_cursor_entry(), oil.get_current_dir()
  if not dir or not entry or not entry.id or entry.type ~= 'file' then
    session.preview:set_pane_buf('preview', session.empty):render()
    return
  end
  local path = vim.fs.joinpath(dir, entry.name)
  if vim.fn.filereadable(path) ~= 1 then
    session.preview:set_pane_buf('preview', session.empty):render()
    return
  end
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  session.preview:set_pane_buf('preview', buf):render()
end

function M.preview()
  local session = active
  if not session or api.nvim_get_current_win() ~= session.win then
    return require('oil').open_preview()
  end
  if session.preview then
    local preview = session.preview
    session.preview = nil
    preview:close()
    render(session)
    return
  end
  local area = {}
  geometry(area)
  if area.width < 6 then
    vim.notify('Window too narrow for Oil preview', vim.log.levels.WARN)
    return
  end
  local popup = require('popup')
  session.empty = session.empty or api.nvim_create_buf(false, true)
  local node = { layout = popup.pane({id = 'preview', buf = session.empty,
    border = 'single', win_config = { title = ' Preview ', title_pos = 'center' }}) }
  geometry(node)
  local preview = popup.root(node)
  enable_numbers(preview, 'preview')
  session.preview = preview
  preview:on('close', function()
    if session.preview == preview then
      session.preview = nil
      if active == session then render(session) end
    end
  end)
  render(session)
  preview:open()
  update_preview(session)
end

function M.toggle()
  if active then return M.close() end
  local popup = require('popup')
  local node = { layout = popup.pane({
    id = 'oil', enter = true, border = 'single',
    -- Preserve the source buffer context for oil.open()'s native directory and
    -- cursor selection. This is borrowed, never owned/deleted by popup.
    buf = api.nvim_get_current_buf(),
    win_config = { title = ' Oil ', title_pos = 'center' },
  }) }
  geometry(node)
  local session = { origin = api.nvim_get_current_win() }
  session.popup = popup.root(node)
  local instance = session.popup
  enable_numbers(instance, 'oil')
  local augroup = api.nvim_create_augroup('DotkitOilSession', { clear = true })
  instance:on('close', function()
    instance:leave_group()
    local preview = session.preview
    session.preview = nil
    if preview then preview:close() end
    if session.empty and api.nvim_buf_is_valid(session.empty) then
      api.nvim_buf_delete(session.empty, { force = true })
    end
    api.nvim_del_augroup_by_id(augroup)
    if active == session then active = nil end
  end)
  instance:join_group('single_popup')
  active = session
  instance:open()
  session.win = instance:pane('oil').win
  -- The pane initially borrows the source buffer; Oil owns subsequent buffers.
  api.nvim_create_autocmd('WinClosed', {
    group = augroup, pattern = tostring(session.win),
    callback = function()
      vim.schedule(function()
        if active == session then M.close() end
      end)
    end,
  })
  api.nvim_create_autocmd('VimResized', {
    group = augroup,
    callback = function()
      if not api.nvim_win_is_valid(session.win) then return end
      render(session)
    end,
  })
  api.nvim_create_autocmd({ 'CursorMoved', 'BufEnter' }, {
    group = augroup,
    callback = function()
      -- bufload must run outside autocmds so BufRead/FileType can initialize
      -- syntax, Tree-sitter and filetype plugins for newly previewed files.
      vim.schedule(function()
        if active == session then update_preview(session) end
      end)
    end,
  })
  local ok, err = pcall(require('oil').open)
  if not ok then M.close(); error(err) end
end

return M
