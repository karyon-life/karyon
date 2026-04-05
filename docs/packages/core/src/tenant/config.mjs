import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parse as parseYaml } from 'yaml';

/**
 * @template T
 * @param {T} tenantConfig
 * @returns {T}
 */
export function defineTreeseedTenant(tenantConfig) {
	return tenantConfig;
}

/**
 * @param {string} [manifestPath]
 */
export function loadTreeseedManifest(manifestPath = './src/manifest.yaml') {
	const source = readFileSync(resolve(process.cwd(), manifestPath), 'utf8');
	return defineTreeseedTenant(parseYaml(source));
}

export const loadTreeseedTenantManifest = loadTreeseedManifest;

/**
 * @param {{ content: Record<string, string> }} tenantConfig
 * @param {string} collectionName
 */
export function getTenantContentRoot(tenantConfig, collectionName) {
	const root = tenantConfig.content[collectionName];
	if (!root) {
		throw new Error(`Unknown tenant content collection: ${collectionName}`);
	}

	return root;
}

/**
 * @param {{ features?: Record<string, boolean | undefined> }} tenantConfig
 * @param {string} featureName
 */
export function tenantFeatureEnabled(tenantConfig, featureName) {
	return tenantConfig.features?.[featureName] !== false;
}
