import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse as parseYaml } from 'yaml';

function resolvePackageRoot() {
	const moduleUrl = typeof import.meta?.url === 'string' ? import.meta.url : null;
	if (!moduleUrl) {
		return process.cwd();
	}

	return resolve(dirname(fileURLToPath(moduleUrl)), '../..');
}

const packageRoot = resolvePackageRoot();
const packageFixtureRoot = resolve(packageRoot, 'fixture');

function collectTenantRootCandidates(start) {
	const candidates = [];
	let current = resolve(start);

	while (true) {
		candidates.push(current, resolve(current, 'fixture'));
		const parent = resolve(current, '..');
		if (parent === current) {
			break;
		}
		current = parent;
	}

	return candidates;
}

function uniqueCandidates(entries) {
	return [...new Set(entries.map((entry) => resolve(entry)))];
}

function tenantRootCandidates() {
	return uniqueCandidates([
		...collectTenantRootCandidates(process.cwd()),
		...collectTenantRootCandidates(packageRoot),
		packageFixtureRoot,
	]);
}

function resolveTenantPath(manifestPath) {
	if (existsSync(manifestPath)) {
		return resolve(manifestPath);
	}

	const candidates = [
		...tenantRootCandidates().map((root) => resolve(root, manifestPath)),
	];

	for (const candidate of candidates) {
		if (existsSync(candidate)) {
			return candidate;
		}
	}

	throw new Error(
		`Unable to resolve Treeseed tenant manifest at "${manifestPath}" from ${process.cwd()} or ${packageFixtureRoot}.`,
	);
}

function resolveTenantRoot() {
	const candidates = tenantRootCandidates();

	for (const candidate of candidates) {
		if (existsSync(resolve(candidate, 'src/manifest.yaml'))) {
			return candidate;
		}
	}

	throw new Error(
		`Unable to resolve a Treeseed tenant root from ${process.cwd()} or ${packageFixtureRoot}.`,
	);
}

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
	const resolvedManifestPath = resolveTenantPath(manifestPath);
	const tenantRoot = resolve(dirname(resolvedManifestPath), '..');
	const parsed = parseYaml(readFileSync(resolvedManifestPath, 'utf8'));
	const tenantConfig = defineTreeseedTenant({
		...parsed,
		siteConfigPath: resolve(tenantRoot, parsed.siteConfigPath),
		content: Object.fromEntries(
			Object.entries(parsed.content ?? {}).map(([collectionName, rootPath]) => [
				collectionName,
				resolve(tenantRoot, String(rootPath)),
			]),
		),
	});

	Object.defineProperty(tenantConfig, '__tenantRoot', {
		value: tenantRoot,
		enumerable: false,
	});

	return tenantConfig;
}

export const loadTreeseedTenantManifest = loadTreeseedManifest;
export const resolveTreeseedTenantRoot = resolveTenantRoot;

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
