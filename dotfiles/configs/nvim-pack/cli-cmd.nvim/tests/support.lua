-- Shared helpers for the test suite. Loaded by tests/run.lua, not a test file.
local M = {}

---The plugin under test.
M.root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')

---Put a plugin from `nvim-pack/` on the runtimepath, for the cases that need two
---local plugins to talk to each other. Returns false when this checkout does not
---have it, so the test can say it skipped instead of failing.
---@param name string Directory name, e.g. `terminal.nvim`
---@return boolean
function M.sibling(name)
  local path = vim.fn.fnamemodify(M.root, ':h') .. '/' .. name
  if vim.fn.isdirectory(path) ~= 1 then
    return false
  end
  vim.opt.runtimepath:prepend(path)
  return true
end

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

---Build the Git tool's command directly, for tests that need a Command without
---installing one. Installation would resolve these parts itself; here the caller
---passes both halves in one table.
---@param options table Spec fields plus `cwd`, `presenter` and `editor`.
function M.git_command(options)
  local parts = { cwd = options.cwd, presenter = options.presenter, editor = options.editor }
  return require('cli-cmd.tools.git.command').build(options, parts)
end

---Create a temporary repository with one commit and a `feature-one` branch.
---The branch name every fixture repository starts on.
---
---It is set here rather than left to the machine: `init.defaultBranch` comes from
---whichever git is first on PATH (Homebrew git says `master`, Apple's says `main`
---because of the system gitconfig), so a test that guessed the name would be
---testing the developer's PATH instead of the plugin.
M.branch = 'trunk'

function M.temp_repo()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, 'p')
  M.ok(root, { 'git', 'init', '--quiet', '--initial-branch', M.branch })
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
