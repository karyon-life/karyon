import { resolve } from 'node:path';
import { runLocalD1Migrations } from './d1-migration-lib.mjs';

const tenantRoot = process.cwd();
const migrationsRoot = resolve(tenantRoot, 'migrations');
const wranglerConfig = resolve(tenantRoot, 'wrangler.toml');

runLocalD1Migrations({
	cwd: tenantRoot,
	wranglerConfig,
	migrationsRoot,
});
