import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const composeFile = resolve(process.cwd(), 'compose.yml');

const result = spawnSync('docker', ['compose', '-f', composeFile, 'logs', '-f', 'mailpit'], {
	stdio: 'inherit',
	cwd: process.cwd(),
	env: { ...process.env },
});

process.exit(result.status ?? 1);
