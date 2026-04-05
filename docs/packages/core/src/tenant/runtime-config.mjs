import { loadTreeseedManifest } from './config.mjs';

const injectedTenantConfig =
	typeof __TREESEED_TENANT_CONFIG__ !== 'undefined' ? __TREESEED_TENANT_CONFIG__ : null;
const injectedProjectRoot =
	typeof __TREESEED_PROJECT_ROOT__ !== 'undefined' ? __TREESEED_PROJECT_ROOT__ : null;
const injectedSiteConfig =
	typeof __TREESEED_SITE_CONFIG__ !== 'undefined' ? __TREESEED_SITE_CONFIG__ : null;

export const RUNTIME_TENANT = injectedTenantConfig ?? loadTreeseedManifest();
export const RUNTIME_PROJECT_ROOT = injectedProjectRoot ?? process.cwd();
export const RUNTIME_SITE_CONFIG = injectedSiteConfig ?? null;
