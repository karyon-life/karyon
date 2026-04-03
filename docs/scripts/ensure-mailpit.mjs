import { spawnSync } from 'node:child_process';

const checkDocker = spawnSync('docker', ['info'], {
	stdio: 'ignore',
});

if (checkDocker.status !== 0) {
	console.error('Docker is required for docs form email testing. Start Docker and rerun `npm run mailpit:up`.');
	process.exit(1);
}

const result = spawnSync('docker', ['compose', '-f', 'compose.yml', 'up', '-d', 'mailpit'], {
	stdio: 'inherit',
});

process.exit(result.status ?? 1);
