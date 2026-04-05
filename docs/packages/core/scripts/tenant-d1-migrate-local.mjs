import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { runNodeBinary, wranglerBin } from './package-tools.mjs';

const tenantRoot = process.cwd();
const migrationsRoot = resolve(tenantRoot, 'migrations');
const wranglerConfig = resolve(tenantRoot, 'wrangler.toml');

for (const migration of [
	'0001_subscribers.sql',
	'0002_agent_runtime.sql',
	'0003_agent_run_trace.sql',
]) {
	const file = resolve(migrationsRoot, migration);
	if (!existsSync(file)) {
		console.error(`Unable to find migration file at ${file}.`);
		process.exit(1);
	}

	runNodeBinary(wranglerBin, [
		'd1',
		'execute',
		'karyon-docs-subscribers',
		'--local',
		'--config',
		wranglerConfig,
		'--file',
		file,
	], { cwd: tenantRoot });
}
