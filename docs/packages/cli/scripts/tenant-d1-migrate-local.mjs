import { resolve } from 'node:path';
import { runLocalD1Migrations } from './d1-migration-lib.mjs';
import { ensureGeneratedWranglerConfig } from './deploy-lib.mjs';

const tenantRoot = process.cwd();
const migrationsRoot = resolve(tenantRoot, 'migrations');
const { wranglerPath: wranglerConfig } = ensureGeneratedWranglerConfig(tenantRoot);

runLocalD1Migrations({
	cwd: tenantRoot,
	wranglerConfig,
	migrationsRoot,
});
