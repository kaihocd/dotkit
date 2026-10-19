import type { ActionRequirements } from "../software";

export interface ExecutionAuthorization {
  /** Authorizes deployment writes and the platform's trusted callbacks. */
  readonly deployment: boolean;
  readonly network: boolean;
  readonly elevatedPrivileges: boolean;
}

/** Shared policy for preflight and action-time checks; never invokes sudo. */
export function allowsAction(
  requirements: ActionRequirements,
  authorization: ExecutionAuthorization,
): boolean {
  return (
    authorization.deployment &&
    (!requirements.network || authorization.network) &&
    (!requirements.elevatedPrivileges || authorization.elevatedPrivileges)
  );
}
