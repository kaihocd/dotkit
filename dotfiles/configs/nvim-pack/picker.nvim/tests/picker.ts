import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
for (const test of [
  "config",
  "picker-controller",
  "picker-search",
  "picker-list",
  "picker-input",
  "picker-bindings",
  "picker-view",
  "picker-layout",
  "picker-layout-ratios",
  "picker-viewport",
  "picker-session",
  "picker-completion",
  "picker-backend",
  "picker-scheduling",
  "picker-icons",
  "picker-format",
  "picker-presentation",
  "presentation-content",
  "list-highlight-composition",
  "picker-public-grep-presentation",
  "picker-preview-content",
  "picker-preview-queue",
  "picker-preview-version",
  "picker-preview-cache",
  "picker-preview-ui",
  "picker-preview-navigation",
  "picker-preview-prefetch",
  "picker-grep-view",
  "picker-grep-session",
  "picker-syntax",
  "picker-signs",
  "picker-theme",
  "picker-replacement",
  "picker-group-errors",
  "picker-options",
  "picker-action-errors",
  "picker-snapshot",
  "picker-restore",
  "picker-resume-session",
  "picker-resume",
  "picker-resume-hooks",
  "picker-session-retry",
]) {
  const result = spawnSync(
    "nvim",
    ["--headless", "-u", "NONE", "-l", resolve(root, `tests/${test}.lua`)],
    {
      cwd: root,
      stdio: "inherit",
      timeout: 30_000,
    },
  );
  if (result.error) console.error(result.error.message);
  if (result.status !== 0) process.exit(result.status ?? 1);
}
