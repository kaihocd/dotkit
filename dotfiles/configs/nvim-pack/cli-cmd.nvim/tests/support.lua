-- Shared helpers for the test suite. Loaded by tests/run.lua, not a test file.
local M = {}

function M.run(cwd, args)
  local process = vim.system(args, { cwd = cwd, text = true })
  local completed = process:wait(20000)
  assert(completed, 'timed out: ' .. table.concat(args, ' '))
  return completed
end

function M.ok(cwd, args)
  local completed = M.run(cwd, args)
  assert(completed.code == 0, table.concat(args, ' ') .. ' failed: ' .. tostring(completed.stderr))
  return completed
end

---Create a temporary repository with one commit and a `feature-one` branch.
function M.temp_repo()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, 'p')
  M.ok(root, { 'git', 'init', '--quiet' })
  M.ok(root, { 'git', 'config', 'user.email', 'test@example.com' })
  M.ok(root, { 'git', 'config', 'user.name', 'Test' })
  vim.fn.writefile({ 'fixture' }, root .. '/tracked.txt')
  M.ok(root, { 'git', 'add', 'tracked.txt' })
  M.ok(root, { 'git', 'commit', '--quiet', '-m', 'init' })
  M.ok(root, { 'git', 'branch', 'feature-one' })
  return root
end

function M.stage(root, name, lines)
  vim.fn.writefile(lines, root .. '/' .. name)
  M.ok(root, { 'git', 'add', name })
end

return M
