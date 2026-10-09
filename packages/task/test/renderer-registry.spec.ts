import { describe, expect, it } from "vitest";
import { selectRendererId } from "../src/rendering/builtins";
import {
  RendererRegistry,
  type RendererContext,
  type TaskRenderer,
  type TaskRendererDefinition,
  type Terminal,
} from "../src/rendering/core";

const terminal: Terminal = {
  columns: 80,
  rows: 24,
  write() {},
  clearLines() {},
  hideCursor() {},
  showCursor() {},
};

describe("RendererRegistry", () => {
  it("creates a newly registered Renderer without changing the Task runtime", () => {
    const renderer: TaskRenderer = {
      attach() {},
      dispose() {},
    };
    const card: TaskRendererDefinition = {
      id: "card",
      create(context: RendererContext) {
        expect(context.terminal).toBe(terminal);
        return renderer;
      },
    };
    const registry = new RendererRegistry([card]);

    expect(registry.create("card", { terminal })).toBe(renderer);
  });

  it("selects a Renderer only from terminal interactivity", () => {
    expect(selectRendererId(true)).toBe("tree");
    expect(selectRendererId(false)).toBe("plain");
  });
});
