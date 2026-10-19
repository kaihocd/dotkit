import type { ExecutionAuthorization } from "./authorization";
export type { ExecutionAuthorization } from "./authorization";

export interface ExecutionOptions {
  readonly cwd: string;
  readonly variables: Readonly<Record<string, string | undefined>>;
  readonly authorize: ExecutionAuthorization;
}

export type ExecutionStepStatus =
  "completed" | "skipped" | "blocked" | "failed" | "not-run";

export interface ExecutionStep {
  readonly software: string;
  readonly action: "install" | "build" | "links";
  readonly status: ExecutionStepStatus;
  readonly reason?: string;
}

export interface HookResult {
  readonly action: "preInstall" | "postInstall";
  readonly status: ExecutionStepStatus;
  readonly reason?: string;
}

export interface DeploymentResult {
  readonly hooks: HookResult[];
  readonly steps: readonly ExecutionStep[];
}
