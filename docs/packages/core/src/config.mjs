import starlight from '@astrojs/starlight';
import { createTreeseedSite } from './site.mjs';
import { loadTreeseedManifest } from './tenant/config.mjs';

export function createTreeseedTenantSite(manifestPath) {
	const tenant = loadTreeseedManifest(manifestPath);
	return createTreeseedSite(tenant, { starlight });
}
