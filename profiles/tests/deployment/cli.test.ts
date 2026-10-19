import assert from "node:assert/strict";
import { test } from "node:test";
import { deploymentStatus, selectPlatform } from "../../scripts/deploy";
import type { ExecutionStepStatus } from "../../src/deployment/execute";

test("platform selection accepts only an in-range integer", () => {
  assert.equal(selectPlatform(" 2 ", ["macos", "arch"]), "arch");
  for (const answer of [
    "",
    "0",
    "-1",
    "1abc",
    "1.0",
    "1e0",
    "01",
    "3",
    "99999999999999999999",
  ]) {
    assert.throws(
      () => selectPlatform(answer, ["macos", "arch"]),
      /Choose a number/,
    );
  }
});

test("CLI summary cannot report failed or unfinished execution as completed", () => {
  const states: ExecutionStepStatus[] = [
    "completed",
    "skipped",
    "failed",
    "blocked",
    "not-run",
  ];
  for (const status of states) {
    const expected =
      status === "completed" || status === "skipped" ? "completed" : "failed";
    assert.equal(
      deploymentStatus({
        hooks: [],
        steps: [{ software: "fixture", action: "build", status }],
      }),
      expected,
    );
    assert.equal(
      deploymentStatus({
        hooks: [{ action: "postInstall", status }],
        steps: [],
      }),
      expected,
    );
  }
});
