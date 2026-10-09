import { ExpectedError } from "@dotkit/shared/error";

export class TaskError extends ExpectedError {}

/** Signals an already-rendered non-zero task result, not a new diagnostic. */
export class TaskFailedError extends TaskError {}
