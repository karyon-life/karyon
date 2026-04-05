import type { TreeseedTenantConfig } from '../contracts';

export function defineTreeseedTenant<T>(tenantConfig: T): T;
export function loadTreeseedManifest(manifestPath?: string): TreeseedTenantConfig;
export const loadTreeseedTenantManifest: typeof loadTreeseedManifest;
export function getTenantContentRoot(
	tenantConfig: Pick<TreeseedTenantConfig, 'content'>,
	collectionName: string,
): string;
export function tenantFeatureEnabled(
	tenantConfig: Pick<TreeseedTenantConfig, 'features'>,
	featureName: string,
): boolean;
