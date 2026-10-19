/** Public deployment API. Platform implementations remain dynamically loaded. */
export { Deployment } from "./deployment";
export { PlatformLoader } from "./platform";
export { resolveEnvironment } from "./platform/environment";
export type { PlatformConfiguration } from "./platform";
export type { DeploymentResult } from "./deployment";
