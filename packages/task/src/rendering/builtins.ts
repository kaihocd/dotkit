import {
  RendererRegistry,
  type TaskRenderer,
  type TaskRendererDefinition,
} from "./core";
import { PlainTreeRenderer } from "./renderers/plain";
import { InteractiveTreeRenderer } from "./renderers/tree/renderer";
import { StderrTerminal, StdoutTerminal } from "./terminal";

const BUILTIN_RENDERERS = [
  {
    id: "plain",
    create: ({ terminal }) => new PlainTreeRenderer(terminal),
  },
  {
    id: "tree",
    create: ({ terminal }) => new InteractiveTreeRenderer(terminal),
  },
] satisfies readonly TaskRendererDefinition[];

const registry = new RendererRegistry(BUILTIN_RENDERERS);

export function selectRendererId(interactive: boolean): "plain" | "tree" {
  return interactive ? "tree" : "plain";
}

/** Creates the built-in Renderer appropriate for the current terminal. */
export function createRenderer(): TaskRenderer {
  const interactive = process.stderr.isTTY === true;
  const terminal = interactive ? new StderrTerminal() : new StdoutTerminal();
  return registry.create(selectRendererId(interactive), { terminal });
}
