import type { TaskEvent, TaskStateSource, TaskStateTree } from "../../../types";
import type { TaskRenderer, Terminal } from "../../core";
import { TreeView } from "./view";

export interface InteractiveRendererOptions {
  readonly liveOutputLines?: number;
  readonly spinnerIntervalMs?: number;
}

const SPINNER_FRAME_COUNT = 10;
const OUTPUT_REDRAW_INTERVAL_MS = 50;

/** TTY Renderer controller: subscription, timing, redraw, and cursor lifecycle. */
export class InteractiveTreeRenderer implements TaskRenderer {
  private readonly liveOutputLines: number;
  private readonly spinnerIntervalMs: number;
  private source?: TaskStateSource;
  private unsubscribe?: () => void;
  private timer?: NodeJS.Timeout;
  private outputRedrawTimer?: NodeJS.Timeout;
  private animationFrame = 0;
  private renderedLineCount = 0;
  private standaloneRunIds: number[] = [];

  public constructor(
    private readonly terminal: Terminal,
    options: InteractiveRendererOptions = {},
  ) {
    this.liveOutputLines = options.liveOutputLines ?? 3;
    this.spinnerIntervalMs = options.spinnerIntervalMs ?? 350;
  }

  public attach(source: TaskStateSource): void {
    this.dispose();
    this.source = source;
    this.terminal.hideCursor();
    this.unsubscribe = source.subscribe((tree, event) => {
      this.handleEvent(tree, event);
    });
    this.timer = setInterval(() => {
      this.animationFrame = (this.animationFrame + 1) % SPINNER_FRAME_COUNT;
      this.redraw();
    }, this.spinnerIntervalMs);
    this.timer.unref();
  }

  public dispose(): void {
    this.finishStandalone();
    this.unsubscribe?.();
    this.unsubscribe = undefined;
    if (this.timer) clearInterval(this.timer);
    this.timer = undefined;
    this.cancelOutputRedraw();
    if (this.source) this.terminal.showCursor();
    this.source = undefined;
  }

  private handleEvent(tree: TaskStateTree, event: TaskEvent): void {
    if (event.type === "command-output") {
      this.scheduleOutputRedraw();
      return;
    }

    this.cancelOutputRedraw();
    const view = this.view();
    if (event.type === "workspace-started") {
      this.finishStandalone();
      this.clearDashboard();
      this.terminal.write(view.renderWorkspaceStart(event.id));
      return;
    }
    if (event.type === "command-started" && event.parentRunId === undefined) {
      const node = tree.nodes.get(event.runId);
      if (node) {
        if (this.standaloneRunIds.length === 0) {
          this.clearDashboard();
          this.terminal.write(view.renderStandaloneStart(node));
        }
        this.standaloneRunIds.push(node.runId);
      }
    }
    if (event.type === "command-finished") {
      const node = tree.nodes.get(event.runId);
      const parent =
        node?.parentRunId === undefined
          ? undefined
          : tree.nodes.get(node.parentRunId);
      if (node && node.parentRunId === undefined) {
        this.clearDashboard();
        this.terminal.write(view.renderStandaloneCommand(tree, node));
      }
      if (node && parent?.type === "workspace") {
        this.clearDashboard();
        this.terminal.write(view.renderCompletedCommand(tree, node));
      }
      this.redraw(tree);
      return;
    }

    if (event.type === "workspace-finished") {
      this.clearDashboard();
      const workspace = tree.nodes.get(event.runId);
      if (workspace)
        this.terminal.write(view.renderWorkspaceResult(tree, workspace));
      return;
    }

    this.redraw(tree);
  }

  private finishStandalone(): void {
    const tree = this.source?.snapshot();
    if (!tree || this.standaloneRunIds.length === 0) return;
    const nodes = this.standaloneRunIds.flatMap((id) => {
      const node = tree.nodes.get(id);
      return node ? [node] : [];
    });
    this.clearDashboard();
    if (nodes.every((node) => node.status !== "running")) {
      this.terminal.write(this.view().renderStandaloneResult(nodes));
    }
    this.standaloneRunIds = [];
  }

  private scheduleOutputRedraw(): void {
    if (this.outputRedrawTimer) return;
    this.outputRedrawTimer = setTimeout(() => {
      this.outputRedrawTimer = undefined;
      this.redraw();
    }, OUTPUT_REDRAW_INTERVAL_MS);
    this.outputRedrawTimer.unref();
  }

  private cancelOutputRedraw(): void {
    if (this.outputRedrawTimer) clearTimeout(this.outputRedrawTimer);
    this.outputRedrawTimer = undefined;
  }

  private clearDashboard(): void {
    this.terminal.clearLines(this.renderedLineCount);
    this.renderedLineCount = 0;
  }

  private redraw(tree = this.source?.snapshot()): void {
    if (!tree) return;
    const text = this.view().renderDashboard(
      tree,
      this.animationFrame,
      this.standaloneRunIds.length > 0,
    );
    this.clearDashboard();
    this.terminal.write(text);
    this.renderedLineCount = text.split("\n").length - 1;
  }

  private view(): TreeView {
    const dashboardLines = Math.max(1, this.terminal.rows - 1);
    return new TreeView(
      this.terminal.columns,
      this.liveOutputLines,
      dashboardLines,
    );
  }
}
