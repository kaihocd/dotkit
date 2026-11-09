# API reference

Every module is usable on its own. Nothing here registers global state, reads user configuration, or loads `terminal.nvim`; composition happens in the caller.

Dependency direction (top depends on bottom, never the reverse):

```
init ── adapter/git, completion/git, bridge/editor, presenter/notify
adapter/git ─┬─ command ─┬─ dispatcher ── router
             │           ├─ context
             │           ├─ task
             │           └─ backend/{process,native_terminal,terminal}
             ├─ completion/git ── completion
             ├─ bridge/editor
             └─ presenter/notify
```

| Module | Owns | Never does |
| --- | --- | --- |
| `cli.context` | Snapshot of one invocation | Parse Git options, pick a backend |
| `cli.router` | Route key → handler | Execute anything |
| `cli.task` | Lifecycle, output ordering, result | Know about processes or buffers |
| `cli.dispatcher` | Create Task → resolve handler → run | Choose handlers |
| `cli.command` | One command definition + `:Command` registration | Know which tool it runs |
| `cli.backend.*` | Start a process / terminal | Decide policy or presentation |
| `cli.presenter.notify` | Turn a finished Task into one notification | Render terminal output |
| `cli.bridge.editor` | Give Git an editor that talks back over RPC | Know which Git command asked |
| `cli.bridge.serve` | The external editor's own script | Not a module: loaded by the child with `dofile` |
| `cli.completion*` | Candidate lists | Execute or route |
| `cli.adapter.git` | Git-specific routing preset and wiring | Force a naming or registration policy |
| `cli` (`init.lua`) | Assembling the pieces in a working order | Register commands implicitly, invent policy |

---

## Entry point

`require('cli').setup(opts)` is a convenience wrapper, not a second API: it builds the same objects the sections below describe and returns them.

```lua
local app = require('cli').setup({
  cwd = vim.fn.getcwd(),
  editor = { layout = 'tab' }, -- false/nil keeps editing untouched
  routes = { log = 'process' }, -- merged into the Git preset
  completion = { cache_ttl = 5000 }, -- false disables
  presenter = false,                 -- false disables
})
app.register('MyGit')
local task = app.command:dispatch({ argv = { 'status' }, raw_input = 'status', route_key = 'status' })
app.dispose()
```

| Option | Default | Notes |
| --- | --- | --- |
| `cwd` | `vim.fn.getcwd()` | Passed to the adapter and used as the editor bridge root |
| `adapter` | `'git'` | Only `'git'` has a preset; other names fail at `setup` time |
| `editor` | `false` | Table of `cli.bridge.editor` options; `false`/`nil` never installs a bridge |
| `completion` | `true` | `true` builds `cli.completion.git` for the same `cwd`/`executable`; a table is forwarded; `false` disables |
| `presenter` | `true` | `true` builds `cli.presenter.notify`; a table is used as-is; `false` disables |
| `executable` | `'git'` | Forwarded to the adapter and the completion provider |
| `routes` / `replace_routes` / `fallback` / `backends` / `env` / `terminal_capability` / `terminal_layout` | — | Forwarded unchanged to `cli.adapter.git.new` |

The result is a plain table:

| Field | Type | Notes |
| --- | --- | --- |
| `cwd` | `string` | Resolved working directory |
| `command` | table | The adapter instance; `:dispatch` and `:register` are the same methods as below |
| `editor` | table? | The bridge when requested, otherwise `nil` |
| `completion` | `function?` | The completion callback, otherwise `nil` |
| `presenter` | table \| `false` | The presenter instance, or `false` when disabled |
| `register(name, opts?)` | function | Registers `:name`, defaulting `route_key` to the adapter's and recording it for `dispose` |
| `dispose()` | function | Deletes commands registered through `register` and disposes the bridge; idempotent |

Nothing is registered implicitly: `setup` alone creates no user command, no global state, and no autocmd. The editor bridge is the one component that is not on by default, because it needs a reachable Neovim server and fails loudly without one.

---

## Context

`require('cli.context').new(input)`

| Field | Type | Notes |
| --- | --- | --- |
| `executable` | `string` | Resolved program name, e.g. `'git'` |
| `argv` | `string[]` | Arguments, executable excluded. Needs to be a list |
| `raw_input` | `string` | The argument text as the user typed it |
| `cwd` | `string` | Explicit execution directory, must exist |
| `env` | `table<string,string>?` | Per-invocation environment overrides |
| `route_key` | `string?` | Supplied by the adapter; never inferred from `argv[1]` |

```lua
local Context = require('cli.context')
local ctx = Context.new({
  executable = 'git',
  argv = { 'status', '--short' },
  raw_input = 'status --short',
  cwd = vim.fn.getcwd(),
  route_key = 'status',
})
```

Context is a validated copy: it does not read the environment, resolve paths, or interpret flags.

---

## Router

`require('cli.router').new({ handlers, routes, fallback })` → `router:resolve(ctx)`

- `handlers`: `table<string, fun(ctx, task)>` — names to functions.
- `routes`: `table<string, string|function>` — route key to a handler name or an inline function.
- `fallback`: handler name or function; defaults to `'terminal'`.

Both `routes` and `fallback` are resolved at construction, so an unknown name fails immediately with `cli.router: unknown handler: <name>` instead of at dispatch time. Because the default fallback is `'terminal'`, a `handlers` table without an entry of that name needs an explicit `fallback`.

```lua
local Router = require('cli.router')
local router = Router.new({
  handlers = {
    quiet = function(_, task) task:complete({ kind = 'exit', code = 0 }) end,
    interactive = function(_, task) task:complete({ kind = 'delegated', target = 'terminal' }) end,
  },
  routes = { status = 'quiet', log = 'interactive' },
  fallback = 'interactive',
})
router:resolve({ route_key = 'status' })  -- the quiet function
router:resolve({ route_key = nil })       -- the fallback
```

---

## Task

`require('cli.task').new(metadata?)`

| Method | Result | Notes |
| --- | --- | --- |
| `task:start()` | `task` | `created` → `running` |
| `task:output(stream, data)` | `boolean` | `stream` is `'stdout'` or `'stderr'`; ignored after completion |
| `task:complete(result)` | `boolean` | `running`/`cancelling` → `finished`; rejects a second result |
| `task:finish(result)` | `boolean` | Same, but a finished task returns `false` and a cancelling one reports `cancelled`. Backends use this |
| `task:cancel()` | `boolean` | `running` → `cancelling`; emits `cancel` |
| `task:status()` | `'created'\|'running'\|'cancelling'\|'finished'` | |
| `task:result()` | `table?` | Copy of the terminal result |
| `task:on(callback)` | `fun()` unsubscribe | Events are never replayed |
| `task:annotate(key, value)` | `task` | Scalar execution facts, e.g. output surface |
| `task:metadata()` | `table` | Copy of metadata |

`finish` is the form backends use: it reports what the process saw without deciding whether the task may still be completed, so a late callback cannot overwrite an earlier result and cancellation always wins.

Result kinds — the only four:

```lua
{ kind = 'exit', code = 0 }                  -- finished; code >= 0
{ kind = 'delegated', target = 'terminal' }  -- handed to a terminal; NOT success
{ kind = 'error', message = 'spawn failed' } -- the CLI itself failed
{ kind = 'cancelled' }                       -- user cancelled
```

Events: `{ kind = 'start' }`, `{ kind = 'output', stream, data }`, `{ kind = 'cancel' }`, `{ kind = 'result', result }`.

```lua
local Task = require('cli.task')
local task = Task.new({ command = 'git status' })
local stop = task:on(function(event)
  if event.kind == 'output' then
    io.write(event.stream, event.data)
  elseif event.kind == 'result' then
    print(vim.inspect(event.result))
  end
end)
task:start()
task:output('stdout', 'clean\n')
task:complete({ kind = 'exit', code = 0 })
stop()
```

Because listeners are not replayed, attach before `start()` — a listener added afterwards never sees the `start` event, and one added after `complete()` sees nothing at all. That is why `Dispatcher` offers `on_create`.

---

## Dispatcher

`require('cli.dispatcher').new({ router, task })` → `dispatcher:dispatch(ctx, { on_create })`

Creates a task, calls `on_create(task)` before starting it, then resolves and invokes the handler.

```lua
local Dispatcher = require('cli.dispatcher')
local dispatcher = Dispatcher.new({ router = router, task = require('cli.task') })
local task = dispatcher:dispatch(ctx, {
  on_create = function(created) presenter:attach(created) end,
})
```

---

## Command

`require('cli.command').new(opts)` → `command:dispatch(input)`, `command:register(name, opts)`

| Option | Type | Default | Notes |
| --- | --- | --- | --- |
| `executable` | `string` | required | |
| `cwd` | `string` | required | |
| `backends` | `table<string, fun(ctx, task)>` | `{}` | Overrides the built-in `process`/`terminal` names |
| `routes` | `table<string, string\|function>` | `{}` | Raw definitions; adapters usually supply a preset |
| `fallback` | `string\|function` | `'terminal'` | |
| `terminal_capability` | `{ delegate = fun(ctx, task) }` | none | Replaces the native terminal backend |
| `terminal_layout` | `'tab'\|'split'\|'vsplit'` | `'tab'` | Native terminal placement |
| `env` | `table\|fun(): table?` | none | Function form is evaluated per dispatch |
| `complete` | `fun\|string` | none | Default completion for `register` |
| `presenter` | presenter table \| `false` | `presenter.notify` | `false` disables presentation |

`dispatch(input)` takes `{ argv, raw_input, cwd?, env?, route_key? }`; `cwd`/`env` fall back to the definition.

`register(name, opts)` creates a native user command with `nargs = '*'` and the `fargs` rule (spaces need a backslash; double quotes do not group).

| Register option | Type | Notes |
| --- | --- | --- |
| `route_key` | `string\|fun(fargs, cmdline_opts): string?` | Adapters pass their parser |
| `complete` | `fun\|string` | Overrides the definition default |
| `bang` | `boolean` | Registers `:Cmd!` |
| `force` | `boolean` | Passed to `nvim_create_user_command` |

```lua
local Command = require('cli.command')
local command = Command.new({
  executable = 'sh',
  cwd = vim.fn.getcwd(),
  routes = { status = 'process' },
})
command:register('CliDemo', { complete = 'shellcmd' })
```

---

## Backends

### Process

`require('cli.backend.process').run(ctx, task)`

Runs `{ executable, unpack(argv) }` with `vim.system` in `ctx.cwd`, merging `ctx.env`. It has no tty: stdin is `/dev/null`, so anything interactive must not be routed here. Output streams into the task as `stdout`/`stderr`; the exit code becomes `{ kind = 'exit', code }`. Cancelling stops the job.

A process killed by a signal is never reported as success: it completes with `code = 128 + signal` (SIGINT → 130), matching how a shell reports the same command.

### Native terminal

`require('cli.backend.native_terminal').new({ layout? }):run(ctx, task)` — or `NativeTerminal.run(ctx, task)` for the default layout.

Starts a real `termopen` job in an unlisted scratch buffer and presents it:

| Layout | Placement |
| --- | --- |
| `'tab'` (default) | `tab sbuffer` — new tab, existing view untouched |
| `'split'` | `sbuffer` |
| `'vsplit'` | `vertical sbuffer` |

It owns the buffer and job, streams terminal output into the task, reports the real exit code, and annotates `surface = 'terminal'` so presenters stay quiet. A failed spawn or placement deletes the buffer, completes the task with `{ kind = 'error' }`, and rethrows. The tab stays open after the command exits so output remains readable.

### External terminal capability

`require('cli.backend.terminal').new(capability):run(ctx, task)` — protocol only:

```lua
local capability = {
  delegate = function(ctx, task)
    -- start the command somewhere else; return an optional handle
    return { cancel = function() end }
  end,
}
```

The task always completes as `{ kind = 'delegated', target = 'terminal' }`; sending work to a persistent shell is never reported as `exit 0`. A capability that throws produces `{ kind = 'error' }` and the error is rethrown.

---

## Presenter

`require('cli.presenter.notify').new({ notify?, level? })` → `presenter:attach(task)`

| Result | Output |
| --- | --- |
| `exit 0` with output | one `INFO` message |
| `exit 0` without output | nothing |
| `exit ≠ 0` | `ERROR`, `stdout`/`stderr` merged in arrival order, `exit N` when silent |
| `error` | `ERROR` with `result.message` |
| `cancelled` | `WARN` |
| `delegated` | nothing |
| any result when `task:metadata().surface == 'terminal'` | nothing |

`vim.notify` is resolved when the message is emitted, so overriding it later takes over every surface. `\r\n` and `\r` are normalised to `\n`.

The `level` option is only a fallback for results that carry no inherent level (`delegated`); it is not a threshold. Passing a custom `notify` is how you take over rendering.

```lua
local Notify = require('cli.presenter.notify')
local presenter = Notify.new({
  notify = function(message, level) require('my-notify').show(message, level) end,
})
presenter:attach(task)
```

---

## Editor Bridge

`require('cli.bridge.editor').new({ cwd?, layout?, open?, server? })`

Makes Git ask this Neovim instance to edit commit messages and sequences, without starting a nested Vim.

| Method | Result | Notes |
| --- | --- | --- |
| `bridge:env()` | `{ GIT_EDITOR, GIT_SEQUENCE_EDITOR, CLI_EDITOR_ID, CLI_EDITOR_SERVER }` | A quoted `nvim --clean --headless -n -i NONE -u <config>` command; the config loads `bridge/serve.lua` |
| `bridge:active()` | `boolean` | True while a session is waiting |
| `bridge:cancel(status?)` | `integer` | Cancels every session; returns how many |
| `bridge:dispose()` | — | Deletes the config and unregisters; call on teardown |

Options: `layout` is `'split'` (default), `'vsplit'`, or `'tab'`; `open(path)` overrides placement entirely; `server` defaults to `vim.v.servername` and is required.

The session ends when its window closes, its buffer is wiped, or `bridge:cancel()` runs — not on `:w`. Closing without saving releases Git as usual, so `git commit` aborts with an empty message rather than committing something unintended.

```lua
local EditorBridge = require('cli.bridge.editor')
local bridge = EditorBridge.new({ cwd = cwd, layout = 'tab' })
local git = require('cli.adapter.git').new({ cwd = cwd, editor = bridge })
-- teardown
bridge:dispose()
```

---

## Completion

`require('cli.completion')` — provider plumbing:

| Function | Result | Notes |
| --- | --- | --- |
| `split(text)` | `tokens, current` | Native `fargs` rules |
| `callback(provider)` | `fun(arglead, cmdline, cursorpos): string[]` | Filters by the unfinished token, escapes spaces |

```lua
local Completion = require('cli.completion')
local complete = Completion.callback(function(query)
  return vim.tbl_filter(function(item)
    return item:find(query.arglead, 1, true) == 1
  end, { 'alpha', 'beta' })
end)
```

`require('cli.completion.git').new(opts)` returns a provider; `.callback(opts)` returns a Neovim completion function.

| Option | Type | Default | Notes |
| --- | --- | --- | --- |
| `cwd` | `string` | `vim.fn.getcwd()` | Base directory for refs, paths and discovery |
| `executable` | `string` | `'git'` | |
| `timeout` | `integer` | `1000` | Per Git call, in milliseconds |
| `cache_ttl` | `integer` | `2000` | Memo lifetime for candidate sources |
| `sources` | `table<string, fun(cwd): string[]>` | built-in | Replace `refs`, `remotes`, `authors` or `paths` |
| `discover` | table | real Git | Inject `{ subcommands, vocabulary }` for tests |

It is layered by what Git can answer versus what it cannot:

- `cli.completion.git.discover` asks the installed Git: subcommands from `--list-cmds`, options and nested words from `<cmd> --git-completion-helper`. Options ending in `=` are how value-taking options are detected. Results are cached per `(git version, directory, subcommand)`.
- `cli.completion.git.spec` holds only the gaps: value kinds (`--author=` authors, `--since=` dates, `--onto=` refs, `--file=` paths, `--strategy=` strategies), positional kinds (`checkout` refs, `add` paths, `push <remote> <refspec>`), the options `--git-completion-helper` omits (`--oneline`, `--graph`, `--since=`, …) and the static `strategies`/`dates` lists.
- `cli.completion.git` orchestrates: pending value option, `--opt=value`, `--` paths, options, subcommands, positionals, nested words.

Behaviour:

```text
MyGit commit --<Tab>              -> every option Git reports for commit (no global options)
MyGit commit --author <Tab>       -> authors from git log
MyGit commit --author=<Tab>       -> --author=<author>
MyGit log --since=<Tab>           -> --since=yesterday, --since=2 weeks ago, ...
MyGit stash <Tab>                 -> apply clear drop pop branch list show ...
MyGit push <Tab>                  -> remotes      MyGit push origin <Tab> -> refs
MyGit -C /other add <Tab>         -> paths under /other
MyGit commit -m <Tab>             -> nothing (unknown option: no guessing)
```

Outside a repository `--git-completion-helper` refuses to run, so nothing is offered. That is accepted on purpose, and no fallback list is kept.

```lua
local GitCompletion = require('cli.completion.git')
git:register('MyGit', {
  route_key = require('cli.adapter.git').route_key,
  complete = GitCompletion.callback({ cwd = cwd }),
})
```

---

## Git adapter

`require('cli.adapter.git')`

| API | Result | Notes |
| --- | --- | --- |
| `route_key(argv)` | `string?` | First subcommand after supported global options; `nil` when absent; never mutates `argv` |
| `new(opts)` | Command | Requires `cwd`; adds `editor` support on top of Command options |
| `default_routes()` | `table` | Copy of the preset |
| `default_fallback` | `'terminal'` | Surface for unlisted subcommands |

Routes: `routes` merges over the preset, `replace_routes = true` ignores the preset. `editor` accepts an editor bridge and injects `bridge:env()` per dispatch, so one bridge can serve several commands.

Unknown values fail at construction: `routes` not a table, a target that is neither a non-empty backend name nor a function, or a non-boolean `replace_routes`.

```lua
local Git = require('cli.adapter.git')

local git = Git.new({ cwd = cwd })                                  -- preset
local git2 = Git.new({ cwd = cwd, routes = { log = 'process' } })   -- preset + override
local git3 = Git.new({ cwd = cwd, routes = { status = 'process' }, replace_routes = true })

-- Extend the preset explicitly instead of merging implicitly:
local routes = Git.default_routes()
routes.blame = 'process'
Git.new({ cwd = cwd, routes = routes, replace_routes = true })
```

---

## Complete example

Registered command, Git preset, completion, editor bridge, and one notification per result:

```lua
local cwd = vim.fn.getcwd()
local Git = require('cli.adapter.git')
local GitCompletion = require('cli.completion.git')
local EditorBridge = require('cli.bridge.editor')

local bridge = EditorBridge.new({ cwd = cwd, layout = 'tab' })
local git = Git.new({
  cwd = cwd,
  editor = bridge,
  complete = GitCompletion.callback({ cwd = cwd }),
})
git:register('MyGit', { route_key = Git.route_key })
```

Custom backends and presenter, no Git involved:

```lua
local Command = require('cli.command')
local Notify = require('cli.presenter.notify')

local command = Command.new({
  executable = 'rg',
  cwd = vim.fn.getcwd(),
  backends = {
    quickfix = function(ctx, task)
      require('cli.backend.process').run(ctx, task)
      task:on(function(event)
        if event.kind == 'result' and event.result.kind == 'exit' then
          print('exit', event.result.code)
        end
      end)
    end,
  },
  presenter = Notify.new({ notify = vim.notify }),
  routes = { search = 'quickfix' },
  fallback = 'quickfix',
})
command:register('Rg')
```

---

## Conventions

- Arguments are always argv arrays; no shell string is built. The single exception is the quoted editor command inside `GIT_EDITOR`, which Git itself parses as a shell command.
- Backends complete the task; they never present or decide policy.
- `delegated` is not success.
- A task completes exactly once; late output is dropped.
- User commands follow native `fargs` rules.
- Output goes through `vim.notify` unless the user overrides the presenter.
