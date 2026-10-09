# @dotkit/task

`@dotkit/task` executes Dotkit development commands and publishes their runtime
state independently from terminal presentation.

## Architecture

```text
Preset / CLI
    │ TaskNode
    ▼
TaskRunner ──────► CommandExecutor
    │ TaskEvent          │ OutputChunk / CommandFrame
    ▼                    │
TaskStore ◄──────────────┘
    │ TaskStateTree
    ▼
TaskStateSource
    ├── InteractiveTreeRenderer (TTY redraw)
    └── PlainTreeRenderer       (append-only)
```

Nested `task` processes send the same `TaskEvent` facts to the outer process
through `nested-events.ts`. The outer `TaskStore` remains the single source of
rendering state.

## File responsibilities

| File                                       | Responsibility                                             | Does not own                         |
| ------------------------------------------ | ---------------------------------------------------------- | ------------------------------------ |
| `presets/*.ts`                             | Resolve named Task presets                                 | Execution and rendering              |
| `src/executor.ts`                          | Spawn one process and capture output                       | Task structure and ANSI presentation |
| `src/runner.ts`                            | Execution order, Workspace concurrency, lifecycle events   | Terminal presentation                |
| `src/nested-events.ts`                     | Transport structured events across processes               | Rendering nested text                |
| `src/store.ts`                             | Reduce events into an immutable state tree                 | Execution and view state             |
| `src/rendering/core.ts`                    | Define the Renderer seam and internal registry             | Concrete Renderer knowledge          |
| `src/rendering/builtins.ts`                | Assemble and select the built-in Renderer adapters         | Execution semantics                  |
| `src/rendering/renderers/plain.ts`         | Append-only presentation                                   | Runtime mutation                     |
| `src/rendering/renderers/tree/renderer.ts` | Timer, redraw, commit, and cursor lifecycle                | Tree layout                          |
| `src/rendering/renderers/tree/view.ts`     | Convert state snapshots into the tree layout               | Terminal lifecycle                   |
| `src/rendering/output.ts`                  | Decode, wrap, truncate, style, and filter command output   | Renderer selection                   |
| `src/rendering/terminal.ts`                | Adapt process output streams to the Terminal interface     | Renderer selection                   |
| `cli/index.ts`                             | Assemble Store, transport, Runner, and Renderer lifecycles | Their implementations                |

## Stable Renderer seam

A built-in Renderer is a named definition behind a small creation protocol:

```ts
interface TaskRendererDefinition {
  readonly id: string;
  create(context: RendererContext): TaskRenderer;
}
```

A Renderer itself depends only on the read-only `TaskStateSource` interface:

```ts
interface TaskStateSource {
  snapshot(): TaskStateTree;
  subscribe(subscriber: TaskSubscriber): () => void;
}
```

A replacement Renderer must not call `TaskRunner`, spawn commands, inspect pnpm
output to infer structure, or mutate the Store. Runtime structure comes from
`TaskEvent`; view state such as animation frames, terminal width, committed
nodes, and rendered line count stays inside the Renderer.

## Changing presentation

Tree layout changes should normally touch:

```text
src/rendering/renderers/tree/view.ts
test/renderer.spec.ts
```

Standalone `task exec` in a TTY uses the same task blocks as a Workspace
Package: a project-name header, completed tasks with `Done in …` footers,
and an overall result measured from the first task start to the last task
finish. Completed task output is committed immediately rather than kept in
the viewport-limited Dashboard. The active task stays beneath the fixed project
header, using the same task, output, and status indentation as completed blocks
and the shared `Running…` animation. Project labels use the declared package
name, including its scope. Non-TTY append-only output is unchanged.

Tree refresh/cursor changes belong in
`src/rendering/renderers/tree/renderer.ts`; Plain changes belong in
`src/rendering/renderers/plain.ts`; shared width and output rules belong in
`src/rendering/output.ts`.

Examples include indentation, colors, labels, tree characters, Dashboard
layout, output wrapping, animation, and compact/expanded completed nodes.

If a requested display needs a fact absent from `TaskStateNode`, add that fact
through the complete pipeline:

```text
producer → TaskEvent → nested wire event (when cross-process) → TaskStore → Renderer
```

Examples are PID, retries, cancellation reason, resource usage, or output
timestamps. Renderer code must not infer such facts by parsing third-party text.

To add a new internal style such as `card`:

1. Implement `TaskRenderer` under `src/rendering/renderers/`.
2. Add one internal definition in `src/rendering/builtins.ts`.
3. Add behavior tests for that Renderer.

No changes are required in Core, Runner, Executor, Store, nested transport, or
CLI. Renderer selection is intentionally not a user-facing CLI or environment
option: TTY uses Tree and non-TTY uses Plain.

## Invariants

- Top-level Tasks execute sequentially and fail fast.
- Workspace Package scripts execute concurrently.
- Output is isolated by Run ID and never assigned by parsing rendered text.
- Nested Run IDs are remapped before entering the outer Store.
- A nested node is a child, not an additional root.
- TTY redraw state belongs to `InteractiveTreeRenderer`.
- Non-TTY output is append-only and written to stdout.
- TTY redraw output is written to stderr, leaving stdout available as a data stream.
- Dynamic lines must not auto-wrap, and the transient Dashboard must fit within the terminal viewport.
- Persistent diagnostics must not be lost or bounded by the viewport.
- Renderer disposal restores the cursor and cancels timers.

## Verification

```bash
pnpm --filter @dotkit/task check
pnpm --filter @dotkit/task test
```

For TTY behavior, also run the root command in a real terminal:

```bash
pnpm check
```
