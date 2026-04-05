import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const tenantRoot = process.cwd();
const composeFile = resolve(tenantRoot, 'compose.yml');

if (!existsSync(composeFile)) {
	console.error(`Unable to find compose.yml at ${composeFile}.`);
	process.exit(1);
}

const dockerCheck = spawnSync('docker', ['info'], { stdio: 'ignore' });
if (dockerCheck.status !== 0) {
	console.error('Docker is required for Treeseed form email testing. Start Docker and rerun the Mailpit command.');
	process.exit(1);
}

const result = spawnSync('docker', ['compose', '-f', composeFile, 'up', '-d', 'mailpit'], {
	stdio: 'inherit',
	cwd: tenantRoot,
});

if (result.status !== 0) {
	process.exit(result.status ?? 1);
}
