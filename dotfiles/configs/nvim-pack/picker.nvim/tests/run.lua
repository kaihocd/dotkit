-- Minimal runner: `nvim --clean --headless -i NONE -l tests/run.lua`.
-- A test file returns `function(test)` and calls `test('name', function() ... end)`.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
for _, sibling in ipairs({ 'popup.nvim' }) do
  local path = vim.fn.fnamemodify(root, ':h') .. '/' .. sibling
  if vim.uv.fs_stat(path) then
    vim.opt.runtimepath:prepend(path)
  end
end

local function report(message)
  io.stdout:write(message .. '\n')
end

local passed, failed, skipped = 0, 0, 0
local failures = {}

local file_test = setmetatable({}, {
  __call = function(_, name, body)
    local ok, problem = pcall(body)
    if ok then
      passed = passed + 1
      report(('  PASS  %s'):format(name))
      return
    end
    failed = failed + 1
    failures[#failures + 1] = { name = name, problem = problem }
    report(('  FAIL  %s'):format(name))
  end,
})

function file_test.skip(reason)
  skipped = skipped + 1
  report(('  SKIP  %s'):format(reason or 'no reason given'))
end

local files = vim.fn.globpath(root .. '/tests', '**/*.lua', false, true)
table.sort(files)

for _, file in ipairs(files) do
  if not file:match('run%.lua$') then
    report(('%s'):format(file:sub(#root + 2)))
    local chunk, problem = loadfile(file)
    if not chunk then
      failed = failed + 1
      failures[#failures + 1] = { name = file, problem = problem }
      report(('  FAIL  load: %s'):format(tostring(problem)))
    else
      local ok, body = pcall(chunk)
      if not ok then
        failed = failed + 1
        failures[#failures + 1] = { name = file, problem = body }
        report(('  FAIL  load: %s'):format(tostring(body)))
      else
        local ran, problem_run = pcall(body, file_test)
        if not ran then
          failed = failed + 1
          failures[#failures + 1] = { name = file, problem = problem_run }
          report(('  FAIL  run: %s'):format(tostring(problem_run)))
        end
      end
    end
  end
end

report('')
for _, failure in ipairs(failures) do
  report(('FAIL %s\n  %s'):format(failure.name, tostring(failure.problem)))
end
report(('%d tests, %d failures, %d skipped'):format(passed + failed, failed, skipped))
os.exit(failed == 0 and 0 or 1)
