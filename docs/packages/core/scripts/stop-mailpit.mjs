import { spawnSync } from 'node:child_process';
import { mailpitComposeFile, packageRoot } from './paths.mjs';

const result = spawnSync('docker', ['compose', '-f', mailpitComposeFile, 'down'], {
	stdio: 'inherit',
	cwd: packageRoot,
	env: { ...process.env },
});

process.exit(result.status ?? 1);
