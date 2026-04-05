import type { AstroUserConfig } from 'astro';
import type { TreeseedTenantConfig } from './contracts';

export function createTreeseedSite(
	tenantConfig: TreeseedTenantConfig,
	dependencies: {
		starlight: (config: Record<string, unknown>) => unknown;
	},
): AstroUserConfig;
