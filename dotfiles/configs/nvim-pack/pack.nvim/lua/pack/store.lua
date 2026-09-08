local M = {}

function M.local_target(name)
  return vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'local', 'opt', name)
end

function M.remote_target(name)
  return vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'core', 'opt', name)
end

function M.is_expected_link(target, source)
  local stat = vim.uv.fs_lstat(target)
  return stat ~= nil
    and stat.type == 'link'
    and vim.uv.fs_realpath(target) == vim.uv.fs_realpath(source)
end

local function ownership_path(kind)
  return vim.fs.joinpath(vim.fn.stdpath('state'), 'pack', kind .. '.json')
end

function M.read_ownership(kind)
  local path = ownership_path(kind)
  if not vim.uv.fs_stat(path) then
    return {}
  end
  local lines = vim.fn.readfile(path)
  if #lines == 0 then
    return {}
  end
  return vim.json.decode(table.concat(lines, '\n'))
end

function M.write_ownership(kind, ownership)
  local path = ownership_path(kind)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local temporary = path .. '.tmp'
  vim.fn.writefile({ vim.json.encode(ownership) }, temporary)
  local renamed = vim.uv.fs_rename(temporary, path)
  assert(renamed, 'Unable to write local plugin ownership state')
end

return M
