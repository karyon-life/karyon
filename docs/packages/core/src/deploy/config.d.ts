import type { TreeseedDeployConfig } from '../contracts';

export function resolveTreeseedDeployConfigPath(configPath?: string): string;
export function deriveCloudflareWorkerName(config: TreeseedDeployConfig): string;
export function loadTreeseedDeployConfig(configPath?: string): TreeseedDeployConfig;
