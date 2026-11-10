# API reference

Every module is usable on its own. Nothing here registers global state, reads user configuration, or loads `terminal.nvim`; composition happens in the caller.

Dependency direction (top depends on bottom, never the reverse):

```
init ── install ── tool
tools/git/init ── install ── tools/git/command, tools/git/completion, bridge/editor, presenter/output
                          ── tools/git/command ─┬─ command ─┬─ dispatcher ── router
                                                │           ├─ context
                                                │           ├─ task
                                                │           └─ backend/{process,native_terminal,external_terminal}
                                                ├─ tools/git/completion ── completion
                                                ├─ bridge/editor
                                                └─ presenter/output
```

| Module | Owns | Never does |
| --- | --- | --- |
| `cli-cmd.context` | Snapshot of one invocation | Parse Git options, pick a backend |
| `cli-cmd.router` | Route key → handler | Execute anything |
| `cli-cmd.task` | Lifecycle, output ordering, result | Know about processes or buffers |
| `cli-cmd.dispatcher` | Create Task → resolve handler → run | Choose handlers |
| `cli-cmd.command` | One command definition + `:Command` registration | Know which tool it runs |
| `cli-cmd.backend.*` | Start a process / terminal | Decide policy or presentation |
| `cli-cmd.presenter.output` | Turn a finished Task into one report | Render terminal output |
| `cli-cmd.bridge.editor` | Give Git an editor that talks back over RPC | Know which Git command asked |
| `cli-cmd.tool` | What a tool is: options, names, validation | Create anything |
| `cli-cmd.install` | Turning a spec into user commands, and releasing them | Know Git or any preset |
| `cli-cmd.bridge.serve` | The external editor's own script | Not a module: loaded by the child with `dofile` |
| `cli-cmd.completion*` | Candidate lists | Execute or route |
| `cli-cmd.tools.git.command` | Git's argv rules and its Command builder | Force a naming or registration policy |
| `cli-cmd.tools.git` | The declaration behind `:Git` | Contain anything another tool needs |
| `cli-cmd.tools.palette` | The declaration behind `:Palette`; no routes, everything captured | Need a Command of its own |
| `cli-cmd.tools.brew` | The declaration behind `:Brew`; routing in `command.lua`, candidates in `completion/` | Need a Command of its own |
| `cli-cmd` (`init.lua`) | Loading a built-in tool, or one you declare | Know a tool's routing |

---

## Entry points

Two entry points, both installing user commands and both idempotent by tool name.

`require('cli-cmd').install(name, opts)` loads a built-in tool: the module `lua/cli-cmd/tools/<name>/init.lua`, which returns a `cli-cmd.ToolSpec`. The name is resolved through Neovim's runtime path, and a name with no directory fails as `cli-cmd: no built-in tool: <name>` instead of a Lua module error. `opts` overrides whatever the tool declared, so `install('git')` with no options registers `:Git` exactly as the Git tool describes it.

| Option | Default | Notes |
| --- | --- | --- |
| `command` | `'Git'` | The command's name |
| `alias` | — | `string` or `string[]`; more names for the same command |
| `presets` | — | `{name = {argv?, desc?}}`; `argv` is a preset list, `fargs` are appended |
| `cwd` | current directory | A string pins the directory for every invocation |
| `editor` | `true` | `true` builds a `cli-cmd.bridge.editor` with defaults; `false` installs none |
| `completion` | the tool's provider | `false`, or a `fun(cwd): provider` factory |
| `presenter` | a `cli-cmd.presenter.output` | Any presenter instance, or `false` |
| `routes` / `replace_routes` / `fallback` / `backends` / `env` / `executable` / `terminal_capability` / `terminal_layout` | — | Merged into the spec; the tool's `build` decides what to do with them |

`require('cli-cmd').define(name, spec)` installs a tool that has no directory here. The spec is `cli-cmd.ToolSpec` — `cli-cmd.ToolOptions` plus an optional `build`/`route_key` — with `executable` required and `completion` given as a `fun(cwd): provider` factory; the default command name is `name` with a capital first letter (`brew` → `:Brew`), and the default route for anything unrouted is the terminal backend.

```lua
require('cli-cmd').define('brew', {
  executable = 'brew',
  route_key = function(argv) return argv[1] end,
  routes = { list = 'process' },
  completion = function(cwd) return my_provider end,
})
```

Both return a `cli-cmd.Tool`: `{ name, command, commands, editor, presenter }`. `commands` lists the registered names, the main name first; `command` is the underlying `cli-cmd.command` instance. `require('cli-cmd.install').dispose(name)` releases a tool's commands and editor bridge, and `install` does that automatically before replacing a name.

`cli-cmd.tool` is the part that can be reasoned about without side effects: `validate(spec)` rejects what cannot be installed, `names(spec)` returns the names and the order to register them in. `cli-cmd.install` owns everything that leaves a trace, including the one piece of module-level state in the framework — the map of installed tools by name.

Rules that apply to both:

- The working directory is resolved when the command runs, never at install time, unless `cwd` is given.
- Completion is built once per directory, and preset `argv` reaches the provider as tokens.
- Short names are not implied: `:G` is only Vim's abbreviation of `:Git`, and it becomes ambiguous as soon as another `G*` command exists, so declare `alias = 'G'` when the short form matters.
- Unknown options are rejected (`cli-cmd.tool: unknown option: <key>`), so a typo cannot silently do nothing.
- A name another plugin already registered is refused (`cli-cmd.tool: command already exists: <name>`) rather than taken over, and a failed install rolls back the commands it had created.

---

## Context

`require('cli-cmd.context').new(input)`

| Field | Type | Notes |
| --- | --- | --- |
| `executable` | `string` | Resolved program name, e.g. `'git'` |
| `argv` | `string[]` | Arguments, executable excluded. Needs to be a list |
| `cwd` | `string` | Explicit execution directory, must exist |
| `env` | `table<string,string>?` | Per-invocation environment overrides |
| `route_key` | `string?` | Supplied by the adapter; never inferred from `argv[1]` |

```lua
local Context = require('cli-cmd.context')
local ctx = Context.new({
  executable = 'git',
  argv = { 'status', '--short' },
  cwd = vim.fn.getcwd(),
  route_key = 'capture',
})
```

Context is a validated copy: it does not read the environment, resolve paths, or interpret flags.

---

## Router

`require('cli-cmd.router').new({ handlers, routes, fallback })` → `router:resolve(ctx)`

- `handlers`: `table<string, fun(ctx, task)>` — names to functions.
- `routes`: `table<string, string|function>` — route key to a handler name or an inline function.
- `fallback`: handler name or function; defaults to `'terminal'`.

Both `routes` and `fallback` are resolved at construction, so an unknown name fails immediately with `cli-cmd.router: unknown handler: <name>` instead of at dispatch time. Because the default fallback is `'terminal'`, a `handlers` table without an entry of that name needs an explicit `fallback`.

```lua
local Router = require('cli-cmd.router')
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

`require('cli-cmd.task').new(metadata?)`

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

`cancel` has one caller in the framework: the native terminal backend cancels when its surface goes away (tab closed, buffer wiped), because Neovim leaves the process running and the buffer hidden when a terminal tab closes. A cancelled run reports `cancelled` and its buffer is released.

Result kinds — the only four:

```lua
local results = {
  { kind = 'exit', code = 0 }, -- finished; code >= 0
  { kind = 'delegated', target = 'terminal' }, -- handed to a terminal; NOT success
  { kind = 'error', message = 'spawn failed' }, -- the CLI itself failed
  { kind = 'cancelled' }, -- user cancelled
}
```

Events: `{ kind = 'start' }`, `{ kind = 'output', stream, data }`, `{ kind = 'cancel' }`, `{ kind = 'result', result }`.

```lua
local Task = require('cli-cmd.task')
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

`require('cli-cmd.dispatcher').new({ router, task })` → `dispatcher:dispatch(ctx, { on_create })`

Creates a task, calls `on_create(task)` before starting it, then resolves and invokes the handler.

```lua
local Dispatcher = require('cli-cmd.dispatcher')
local dispatcher = Dispatcher.new({ router = router, task = require('cli-cmd.task') })
local task = dispatcher:dispatch(ctx, {
  on_create = function(created) presenter:attach(created) end,
})
```

---

## Command

`require('cli-cmd.command').new(opts)` → `command:dispatch(input)`, `command:register(name, opts)`

| Option | Type | Default | Notes |
| --- | --- | --- | --- |
| `executable` | `string` | required | |
| `cwd` | `string` | required | |
| `backends` | `table<string, fun(ctx, task)>` | `{}` | Overrides the built-in `process`/`terminal` names |
| `routes` | `table<string, string\|function>` | `Command.standard_routes` | `capture` → `process`, `interactive` → `terminal` |
| `fallback` | `string\|function` | `'terminal'` | |
| `terminal_capability` | `{ delegate = fun(ctx, task) }` | none | Replaces the native terminal backend |
| `terminal_layout` | `'tab'\|'split'\|'vsplit'` | `'tab'` | Native terminal placement |
| `env` | `table\|fun(): table?` | none | Function form is evaluated per dispatch |
| `complete` | `fun\|string` | none | Default completion for `register` |
| `presenter` | presenter table \| `false` | `presenter.output` | `false` disables presentation |

`dispatch(input)` takes `{ argv, cwd?, env?, route_key? }`; `cwd`/`env` fall back to the definition.

`register(name, opts)` creates a native user command with `nargs = '*'` and the `fargs` rule (spaces need a backslash; double quotes do not group).

| Register option | Type | Notes |
| --- | --- | --- |
| `route_key` | `string\|fun(fargs, cmdline_opts): string?` | Adapters pass their parser |
| `complete` | `fun\|string` | Overrides the definition default |
| `bang` | `boolean` | Registers `:Cmd!` |
| `force` | `boolean` | Passed to `nvim_create_user_command` |

```lua
local Command = require('cli-cmd.command')
local command = Command.new({
  executable = 'sh',
  cwd = vim.fn.getcwd(),
  routes = { capture = 'process' },
})
command:register('CliDemo', { complete = 'shellcmd' })
```

---

## Backends

### Process

`require('cli-cmd.backend.process').run(ctx, task)`

Runs `{ executable, unpack(argv) }` with `vim.system` in `ctx.cwd`, merging `ctx.env`. It has no tty: stdin is `/dev/null`, so anything interactive must not be routed here. Output streams into the task as `stdout`/`stderr`; the exit code becomes `{ kind = 'exit', code }`. Cancelling stops the job.

A process killed by a signal is never reported as success: it completes with `code = 128 + signal` (SIGINT → 130), matching how a shell reports the same command.

### Native terminal

`require('cli-cmd.backend.native_terminal').new({ layout? }):run(ctx, task)` — or `NativeTerminal.run(ctx, task)` for the default layout.

Starts a real terminal job (`jobstart` with `term = true`, the spelling Neovim 0.11+ prefers over `termopen`) in an unlisted scratch buffer and presents it:

| Layout | Placement |
| --- | --- |
| `'tab'` (default) | `tab sbuffer` — new tab, existing view untouched |
| `'split'` | `sbuffer` |
| `'vsplit'` | `vertical sbuffer` |

It owns the buffer and job, streams terminal output into the task, reports the real exit code, and annotates `surface = 'terminal'` so presenters stay quiet. A failed spawn or placement deletes the buffer, completes the task with `{ kind = 'error' }`, and rethrows. The tab stays open after the command exits so output remains readable.

### External terminal capability

`require('cli-cmd.backend.external_terminal').new(capability):run(ctx, task)` — protocol only:

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

`require('cli-cmd.presenter.output').new({ notify?, level?, max_lines? })` → `presenter:attach(task)`

| Result | Output |
| --- | --- |
| `exit 0` with output, at most `max_lines` | one `INFO` message |
| any result with more than `max_lines` lines | a scratch tab holding the report |
| `exit 0` without output | nothing |
| `exit ≠ 0` | `ERROR`, `stdout`/`stderr` merged in arrival order, `exit N` when silent |
| `error` | `ERROR` with `result.message` |
| `cancelled` | `WARN` |
| `delegated` | nothing |
| any result when `task:metadata().surface == 'terminal'` | nothing |

`vim.notify` is resolved when the message is emitted, so overriding it later takes over every surface. `\r\n` and `\r` are normalised to `\n`.

`max_lines` (default 15) decides the channel, not the level: a report that does not fit the message area opens in a `nofile` buffer in its own tab, read-only and wiped when closed, so `git log` stays scrollable, searchable, and yankable without a terminal. `max_lines` must be a positive integer.

The `level` option is only a fallback for results that carry no inherent level (`delegated`); it is not a threshold. Passing a custom `notify` is how you take over rendering.

```lua
local Output = require('cli-cmd.presenter.output')
local presenter = Output.new({
  notify = function(message, level) require('my-notify').show(message, level) end,
})
presenter:attach(task)
```

---

## Editor Bridge

`require('cli-cmd.bridge.editor').new({ cwd?, layout?, open?, server? })`

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
local tool = require('cli-cmd').install('git', { editor = { layout = 'tab' } })
local bridge = tool.editor -- the bridge this installation owns
bridge:dispose() -- or release every command it registered
require('cli-cmd.install').dispose('git')
```

---

## Completion

`require('cli-cmd.completion')` — provider plumbing:

| Function | Result | Notes |
| --- | --- | --- |
| `split(text)` | `tokens, current` | Native `fargs` rules |
| `callback(provider)` | `fun(arglead, cmdline, cursorpos): string[]` | Filters by the unfinished token, escapes spaces |

```lua
local Completion = require('cli-cmd.completion')
local complete = Completion.callback(function(query)
  return vim.tbl_filter(function(item)
    return item:find(query.arglead, 1, true) == 1
  end, { 'alpha', 'beta' })
end)
```

`require('cli-cmd.tools.git.completion').new(opts)` returns a provider; `.callback(opts)` returns a Neovim completion function.

| Option | Type | Default | Notes |
| --- | --- | --- | --- |
| `cwd` | `string` | `vim.fn.getcwd()` | Base directory for refs, paths and discovery |
| `executable` | `string` | `'git'` | |
| `timeout` | `integer` | `1000` | Per Git call, in milliseconds |
| `cache_ttl` | `integer` | `2000` | Memo lifetime for candidate sources |
| `sources` | `table<string, fun(cwd): string[]>` | built-in | Replace `refs`, `remotes`, `authors` or `paths` |
| `discover` | table | real Git | Inject `{ subcommands, vocabulary }` for tests |

It is layered by what Git can answer versus what it cannot:

- `cli-cmd.tools.git.completion.discover` asks the installed Git: subcommands from `--list-cmds`, options and nested words from `<cmd> --git-completion-helper`. Options ending in `=` are how value-taking options are detected. Results are cached per `(git version, directory, subcommand)`.
- `cli-cmd.tools.git.completion.spec` holds only the gaps: value kinds (`--author=` authors, `--since=` dates, `--onto=` refs, `--file=` paths, `--strategy=` strategies), positional kinds (`checkout` refs, `add` paths, `push <remote> <refspec>`), the options `--git-completion-helper` omits (`--oneline`, `--graph`, `--since=`, …) and the static `strategies`/`dates` lists.
- `cli-cmd.tools.git.completion` orchestrates: pending value option, `--opt=value`, `--` paths, options, subcommands, positionals, nested words.

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
local GitCompletion = require('cli-cmd.tools.git.completion')
git:register('MyGit', {
  route_key = require('cli-cmd.tools.git.command').route_key,
  complete = GitCompletion.callback({ cwd = cwd }),
})
```

---

## The Git tool

`require('cli-cmd.tools.git')` returns the declaration; `require('cli-cmd.tools.git.command')` is the argv side of it.

| API | Result | Notes |
| --- | --- | --- |
| `route_key(argv)` | `'interactive'\|'capture'` | What the invocation needs from its surface; never mutates `argv` |
| `subcommand(argv)` | `string?` | First subcommand after supported global options; `nil` when absent; never mutates `argv` |
| `build(spec, parts)` | Command | `parts.cwd` is required; `parts.editor` adds the editor environment |
| `default_routes()` | `table` | Copy of the preset |
| `default_fallback` | `'terminal'` | Surface for route keys the preset does not name |

The preset names two surfaces, not subcommands:

| Key | Default backend | Meaning |
| --- | --- | --- |
| `interactive` | `terminal` | The child must talk to a human: it pages, prompts, or holds the keyboard |
| `capture` | `process` | The child runs unattended; the framework reports the result |

`route_key` answers with those keys by reading argv: `-p`, `--patch`, `-i`, `--interactive`, `--paginate`, `--help` anywhere before `--` ask for a conversation, and so do the subcommands that only work with a human (`mergetool`, `bisect`, `help`) and the ones that may ask for a password (`push`, `pull`, `fetch`, `clone`, `submodule`, `ls-remote`). Everything else is captured. The same subcommand can therefore switch surfaces: `add .` is captured, `add -p` is interactive.

Routes: `routes` merges over the preset, `replace_routes = true` ignores the preset. `editor` accepts an editor bridge and injects `bridge:env()` per dispatch, so one bridge can serve several commands.

Unknown values fail at construction: `routes` not a table, a target that is neither a non-empty backend name nor a function, or a non-boolean `replace_routes`.

```lua
local GitCommand = require('cli-cmd.tools.git.command')
local parts = { cwd = cwd, presenter = false }

local git = GitCommand.build({}, parts)                                  -- preset
local git2 = GitCommand.build({ routes = { interactive = 'process' } }, parts)  -- preset + override
local git3 = GitCommand.build({ routes = { capture = 'terminal' }, replace_routes = true }, parts)

-- Extend the preset explicitly instead of merging implicitly:
local routes = GitCommand.default_routes()
routes.capture = 'my-quiet-backend'
GitCommand.build({ routes = routes, replace_routes = true }, parts)
```

---

## Complete example

Registered command, Git preset, completion, editor bridge, and one notification per result:

```lua
require('cli-cmd').install('git', {
  command = 'MyGit',
  editor = { layout = 'tab' },
})
```

Custom backends and presenter, no Git involved:

```lua
local Command = require('cli-cmd.command')
local Output = require('cli-cmd.presenter.output')

local command = Command.new({
  executable = 'rg',
  cwd = vim.fn.getcwd(),
  backends = {
    quickfix = function(ctx, task)
      require('cli-cmd.backend.process').run(ctx, task)
      task:on(function(event)
        if event.kind == 'result' and event.result.kind == 'exit' then
          print('exit', event.result.code)
        end
      end)
    end,
  },
  presenter = Output.new({ notify = vim.notify }),
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
- A module's error prefix is the path it is required by: `lua/cli-cmd/backend/process.lua` says `cli-cmd.backend.process`, `.../init.lua` says nothing extra. `tests/test_guard.lua` fails the suite if a file disagrees, so an error string always leads back to the file that raised it.
- A tool lives in `lua/cli-cmd/tools/<name>/` and its tests in `tests/tools/<name>/`; `lua/cli-cmd/*.lua` never grows when a tool is added.
