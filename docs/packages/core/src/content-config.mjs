import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import { createTreeseedCollections } from './content.mjs';
import { loadTreeseedManifest } from './tenant/config.mjs';

export function createTreeseedTenantCollections(manifestPath) {
	const tenant = loadTreeseedManifest(manifestPath);
	return createTreeseedCollections(tenant, { docsLoader, docsSchema });
}
