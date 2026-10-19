/** Public deployment API. Platform implementations remain dynamically loaded. */
export { Deployment } from "./deployment/execute";
export { PlatformLoader } from "./deployment/platform-discovery";
export { resolveEnvironment } from "./deployment/environment";
export type { PlatformConfiguration } from "./deployment/platform";
export type { DeploymentResult } from "./deployment/execute";
