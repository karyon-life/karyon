import { spawnSync } from 'node:child_process';
import { fixtureComposeFile, packageRoot } from './paths.mjs';

const checkDocker = spawnSync('docker', ['info'], {
	stdio: 'ignore',
});

if (checkDocker.status !== 0) {
	console.error('Docker is required for Treeseed form email testing. Start Docker and rerun the Mailpit command.');
	process.exit(1);
}

const result = spawnSync('docker', ['compose', '-f', fixtureComposeFile, 'up', '-d', 'mailpit'], {
	stdio: 'inherit',
	cwd: packageRoot,
});

process.exit(result.status ?? 1);
