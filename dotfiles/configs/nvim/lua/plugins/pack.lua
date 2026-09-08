local M = {}

local function bootstrap_source()
  local config = assert(
    vim.uv.fs_realpath(vim.fn.stdpath('config')),
    'Unable to resolve Neovim configuration directory'
  )
  return vim.fs.joinpath(vim.fs.dirname(config), 'nvim-pack', 'pack.nvim')
end

local function bootstrap_target()
  return vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'dotkit', 'opt', 'pack.nvim')
end

local function assert_source(source)
  local stat = vim.uv.fs_stat(source)
  assert(stat and stat.type == 'directory', 'Pack bootstrap source is not a directory: ' .. source)
end

local function is_expected_link(target, source)
  local stat = vim.uv.fs_lstat(target)
  if not stat or stat.type ~= 'link' then
    return false
  end
  return vim.uv.fs_realpath(target) == vim.uv.fs_realpath(source)
end

local function ensure_directory(path)
  local missing = {}
  local current = path
  while not vim.uv.fs_stat(current) do
    table.insert(missing, 1, current)
    local parent = vim.fs.dirname(current)
    assert(parent ~= current, 'Unable to resolve Pack bootstrap directory: ' .. path)
    current = parent
  end

  for _, directory in ipairs(missing) do
    local created = vim.uv.fs_mkdir(directory, 493)
    local stat = vim.uv.fs_stat(directory)
    assert(
      created or (stat and stat.type == 'directory'),
      'Unable to create Pack bootstrap directory: ' .. directory
    )
  end
end

local function ensure_link(source, target)
  if is_expected_link(target, source) then
    return
  end

  local occupied = vim.uv.fs_lstat(target)
  assert(not occupied, 'Pack bootstrap target is occupied: ' .. target)

  ensure_directory(vim.fs.dirname(target))
  local linked, error_message = vim.uv.fs_symlink(source, target)
  if linked or is_expected_link(target, source) then
    return
  end

  error('Unable to create Pack bootstrap link: ' .. tostring(error_message))
end

---@param specs? table[]
function M.setup(specs)
  local source = bootstrap_source()
  local target = bootstrap_target()
  assert_source(source)
  ensure_link(source, target)

  vim.cmd.packadd('pack.nvim')
  require('pack').setup(specs or {})
end

return M
