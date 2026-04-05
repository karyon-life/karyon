import type { TreeseedTenantConfig } from './contracts';

export function createTreeseedCollections(
	tenantConfig: TreeseedTenantConfig,
	dependencies: {
		docsLoader: (options: Record<string, unknown>) => unknown;
		docsSchema: (options: Record<string, unknown>) => unknown;
	},
): Record<string, unknown>;
