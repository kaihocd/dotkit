import type { TaskStateNode, TaskStateTree } from "../../../types";
import {
  duration,
  outputLines,
  persistentOutput,
  resultLabel,
  sentenceCase,
  truncateLiveLine,
  truncateStyledLine,
  wrapPersistentLine,
  wrapStyledLine,
  styled,
  type Style,
} from "../../output";

const PACKAGE_STYLES = [
  "cyan",
  "magenta",
  "yellow",
  "blue",
  "green",
] satisfies readonly Style[];
const WORKSPACE_STYLE = "blue" satisfies Style;
const RUNNING_STYLE = "gray" satisfies Style;
const SUCCESS_STYLE = "green" satisfies Style;
const FAILURE_STYLE = "red" satisfies Style;

const PACKAGE_TRACK_COLUMN = 3;

/** Colors structural lanes at the start of a line, preserving Package ownership. */
function colorTrackPrefix(value: string, packageStyle?: Style): string {
  let column = 0;
  let result = "";
  while (column < value.length) {
    const track = value.slice(column).match(/^(?:│|[├└]─)/u)?.[0];
    if (track) {
      const style =
        column === PACKAGE_TRACK_COLUMN && packageStyle
          ? packageStyle
          : RUNNING_STYLE;
      result += styled(track, style);
      column += track.length;
      continue;
    }
    if (value[column] !== " ") break;
    result += " ";
    column += 1;
  }
  return `${result}${value.slice(column)}`;
}

function styleWrappedSuffix(
  lines: readonly string[],
  prefixLength: number,
  suffixStart: number,
  style: Style,
): readonly string[] {
  let contentOffset = 0;
  return lines.map((line) => {
    const prefix = line.slice(0, prefixLength);
    const content = line.slice(prefixLength);
    const localStart = Math.max(0, suffixStart - contentOffset);
    contentOffset += content.length;
    if (localStart >= content.length) return line;
    return `${prefix}${content.slice(0, localStart)}${styled(content.slice(localStart), style)}`;
  });
}

const RUNNING_FRAMES = ["Running   ", "Running.  ", "Running.. ", "Running..."];

/** Pure text layout for the built-in interactive tree Renderer. */
export class TreeView {
  public constructor(
    private readonly columns: number,
    private readonly liveOutputLines: number,
    private readonly dashboardLines: number,
  ) {}

  public renderWorkspaceStart(id: string): string {
    return `${styled(`[${id}]`, WORKSPACE_STYLE)}\n${colorTrackPrefix("│")}\n`;
  }

  public renderDashboard(
    tree: TaskStateTree,
    animationFrame: number,
    standaloneActive = false,
  ): string {
    const lines: string[] = [];
    for (const rootId of tree.roots) {
      const root = tree.nodes.get(rootId);
      if (!root) continue;
      if (root.type === "command") {
        if (root.status !== "running") continue;
        const style = this.packageStyle(tree, root);
        const path = this.activePath(tree, root);
        const label = path.map((node) => `[${node.id}]`).join(" › ");
        lines.push(
          `${colorTrackPrefix("│  ")}${styled(truncateLiveLine(label, this.columns - 4), style)}`,
        );
        this.renderLiveOutput(lines, path.at(-1) ?? root, "│  ", style);
        lines.push(
          `${colorTrackPrefix("│  └─", style)} ${styled(RUNNING_FRAMES[animationFrame % RUNNING_FRAMES.length]!, RUNNING_STYLE)}`,
        );
      } else if (root.status === "running") {
        const children = root.children
          .map((runId) => tree.nodes.get(runId))
          .filter((node): node is TaskStateNode => node !== undefined);
        const runningChildren = children.filter(
          (node) => node.status === "running",
        );
        this.renderRunningChildren(
          lines,
          tree,
          root,
          runningChildren,
          animationFrame,
        );
        const completed = children.length - runningChildren.length;
        const total = root.packageCount ?? children.length;
        if (lines.length > 0) lines.push(colorTrackPrefix("│"));
        lines.push(
          `${colorTrackPrefix("└─")} ${styled(`${completed} of ${total} packages completed`, RUNNING_STYLE)}`,
        );
      }
    }
    if (standaloneActive) {
      lines.push(
        `${colorTrackPrefix("└─")} ${styled(RUNNING_FRAMES[animationFrame % RUNNING_FRAMES.length]!, RUNNING_STYLE)}`,
      );
    }
    if (lines.length <= this.dashboardLines) {
      return lines.length === 0 ? "" : `${lines.join("\n")}\n`;
    }

    if (this.dashboardLines <= 1) return `${lines.at(-1)}\n`;
    const visible = lines.slice(-(this.dashboardLines - 1));
    const hidden = lines.length - visible.length;
    return `${styled(`… ${hidden} earlier dashboard lines`, RUNNING_STYLE)}\n${visible.join("\n")}\n`;
  }

  public renderCompletedCommand(
    tree: TaskStateTree,
    node: TaskStateNode,
  ): string {
    const packageStyle = this.packageStyle(tree, node);
    const packageName = node.projectName ?? node.id;
    const elapsed = duration(node.durationMs ?? 0);
    const footer =
      node.status === "succeeded"
        ? `Done in ${elapsed}`
        : `${sentenceCase(resultLabel(node))} after ${elapsed}`;
    const lines = [
      colorTrackPrefix(
        `│  ${styled(`[${packageName}]`, packageStyle)}`,
        packageStyle,
      ),
    ];
    if (node.children.length > 0) {
      for (const childId of node.children) {
        const child = tree.nodes.get(childId);
        if (child)
          this.renderCompletedNestedNode(
            lines,
            tree,
            child,
            "│  │  ",
            packageStyle,
          );
      }
    } else {
      for (const line of persistentOutput(node)) {
        lines.push(
          ...(line === ""
            ? [colorTrackPrefix("│  │", packageStyle)]
            : wrapStyledLine(line, "│  │  ", "│  │  ", this.columns).map(
                (wrapped) => colorTrackPrefix(wrapped, packageStyle),
              )),
        );
      }
    }
    lines.push(
      ...styleWrappedSuffix(
        wrapPersistentLine(footer, "│  └─ ", "│     ", this.columns),
        6,
        0,
        node.status === "succeeded" ? SUCCESS_STYLE : FAILURE_STYLE,
      ).map((line) => colorTrackPrefix(line, packageStyle)),
      colorTrackPrefix("│"),
    );
    return `${lines.join("\n")}\n`;
  }

  public renderWorkspaceResult(
    tree: TaskStateTree,
    workspace: TaskStateNode,
  ): string {
    const children = workspace.children
      .map((runId) => tree.nodes.get(runId))
      .filter((node): node is TaskStateNode => node !== undefined);
    const failures = children.filter((node) => node.status === "failed");
    const passed = children.length - failures.length;
    const elapsed = duration(workspace.durationMs ?? 0);
    const packageLabel = failures.length === 1 ? "package" : "packages";
    const result =
      failures.length === 0
        ? `${passed} ${passed === 1 ? "package" : "packages"} passed in ${elapsed}`
        : `${failures.length} ${packageLabel} failed, ${passed} passed in ${elapsed}`;
    const resultStyle = failures.length === 0 ? SUCCESS_STYLE : FAILURE_STYLE;
    return `${colorTrackPrefix("└─")} ${styled(result, resultStyle)}\n`;
  }

  private renderRunningChildren(
    lines: string[],
    tree: TaskStateTree,
    parent: TaskStateNode,
    running: readonly TaskStateNode[],
    animationFrame: number,
  ): void {
    for (const [index, child] of running.entries()) {
      const packageStyle = this.packageStyle(tree, child);
      const packageName = child.projectName ?? child.id;
      const path = this.activePath(tree, child);
      const nestedLabels = path.slice(1).map((node) => `[${node.id}]`);
      const identity = `[${packageName}]`;
      const label = [identity, ...nestedLabels].join(" › ");
      const plainLine = truncateLiveLine(`│  ${label}`, this.columns - 1);
      const styledLine = nestedLabels.reduce(
        (line, nestedIdentity) =>
          line.replace(nestedIdentity, styled(nestedIdentity, packageStyle)),
        plainLine.replace(identity, styled(identity, packageStyle)),
      );
      lines.push(
        colorTrackPrefix(
          styledLine.replaceAll("›", styled("›", RUNNING_STYLE)),
          packageStyle,
        ),
      );
      this.renderLiveOutput(lines, path.at(-1) ?? child, "│  ", packageStyle);
      const runningFrame =
        RUNNING_FRAMES[animationFrame % RUNNING_FRAMES.length] ??
        RUNNING_FRAMES[0]!;
      lines.push(
        `${colorTrackPrefix("│  └─", packageStyle)} ${styled(runningFrame, RUNNING_STYLE)}`,
      );
      if (index < running.length - 1) lines.push(colorTrackPrefix("│"));
    }
  }

  private activePath(
    tree: TaskStateTree,
    node: TaskStateNode,
  ): readonly TaskStateNode[] {
    const children = node.children
      .map((runId) => tree.nodes.get(runId))
      .filter((child): child is TaskStateNode => child !== undefined);
    const next =
      children.find((child) => child.status === "running") ?? children.at(-1);
    return next ? [node, ...this.activePath(tree, next)] : [node];
  }

  private renderLiveOutput(
    lines: string[],
    node: TaskStateNode,
    branchIndent: string,
    packageStyle: Style,
  ): void {
    const prefix = `${branchIndent}│  `;
    const availableColumns = Math.max(1, this.columns - prefix.length - 1);
    const allLines = outputLines(node.output).filter(
      (line) => line.trim() !== "",
    );
    const visibleLines = allLines.slice(-this.liveOutputLines);
    const hiddenLineCount = allLines.length - visibleLines.length;
    if (hiddenLineCount > 0) {
      lines.push(
        `${colorTrackPrefix(prefix, packageStyle)}${styled(`… ${hiddenLineCount} earlier lines`, RUNNING_STYLE)}`,
      );
    }
    for (const line of visibleLines) {
      lines.push(
        `${colorTrackPrefix(prefix, packageStyle)}${truncateStyledLine(line, availableColumns)}`,
      );
    }
  }

  private renderCompletedNestedNode(
    lines: string[],
    tree: TaskStateTree,
    node: TaskStateNode,
    prefix: string,
    packageStyle: Style,
  ): void {
    const output = persistentOutput(node);
    const elapsed = duration(node.durationMs ?? 0);
    const result =
      node.status === "succeeded"
        ? `Done in ${elapsed}`
        : `${sentenceCase(resultLabel(node))} after ${elapsed}`;
    const resultStyle =
      node.status === "succeeded" ? SUCCESS_STYLE : FAILURE_STYLE;
    if (node.children.length === 0 && output.length === 0) {
      const identity = `[${node.id}]  `;
      const label = `${identity}${result}`;
      lines.push(
        ...styleWrappedSuffix(
          wrapPersistentLine(label, prefix, `${prefix}  `, this.columns),
          prefix.length,
          identity.length,
          resultStyle,
        ).map((line) =>
          colorTrackPrefix(
            line.replace(`[${node.id}]`, styled(`[${node.id}]`, packageStyle)),
            packageStyle,
          ),
        ),
      );
      return;
    }

    lines.push(
      `${colorTrackPrefix(prefix, packageStyle)}${styled(`[${node.id}]`, packageStyle)}`,
    );
    for (const line of output) {
      lines.push(
        ...(line === ""
          ? [colorTrackPrefix(`${prefix}│`, packageStyle)]
          : wrapStyledLine(
              line,
              `${prefix}│  `,
              `${prefix}│  `,
              this.columns,
            ).map((wrapped) => {
              const outputPrefix = `${prefix}│  `;
              return `${colorTrackPrefix(wrapped.slice(0, outputPrefix.length), packageStyle)}${wrapped.slice(outputPrefix.length)}`;
            })),
      );
    }
    for (const childId of node.children) {
      const child = tree.nodes.get(childId);
      if (child)
        this.renderCompletedNestedNode(
          lines,
          tree,
          child,
          `${prefix}│  `,
          packageStyle,
        );
    }
    const resultPrefixLength = prefix.length + 3;
    lines.push(
      ...styleWrappedSuffix(
        wrapPersistentLine(
          result,
          `${prefix}└─ `,
          `${prefix}   `,
          this.columns,
        ),
        resultPrefixLength,
        0,
        resultStyle,
      ).map((line) => colorTrackPrefix(line, packageStyle)),
    );
  }

  private packageStyle(tree: TaskStateTree, node: TaskStateNode): Style {
    const parent =
      node.parentRunId === undefined
        ? undefined
        : tree.nodes.get(node.parentRunId);
    const packageIndex = parent?.children.indexOf(node.runId) ?? 0;
    return PACKAGE_STYLES[packageIndex % PACKAGE_STYLES.length]!;
  }

  public renderStandaloneStart(node: TaskStateNode): string {
    return `${styled(`[${node.projectName ?? node.id}]`, PACKAGE_STYLES[0]!)}\n`;
  }

  public renderStandaloneCommand(
    tree: TaskStateTree,
    node: TaskStateNode,
  ): string {
    const lines: string[] = [];
    this.renderCompletedNestedNode(
      lines,
      tree,
      node,
      "│  ",
      PACKAGE_STYLES[0]!,
    );
    return `${lines.join("\n")}\n`;
  }

  public renderStandaloneResult(nodes: readonly TaskStateNode[]): string {
    const first = nodes[0];
    const last = nodes.at(-1);
    if (!first || !last) return "";
    const failed = nodes.find((node) => node.status === "failed");
    const elapsed = duration(
      (last.finishedAt ?? last.startedAt) - first.startedAt,
    );
    const result = failed
      ? `${sentenceCase(resultLabel(failed))} after ${elapsed}`
      : `Done in ${elapsed}`;
    return `${colorTrackPrefix("└─")} ${styled(result, failed ? FAILURE_STYLE : SUCCESS_STYLE)}\n`;
  }
}
