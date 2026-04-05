import { spawnSync } from 'node:child_process';
import { packageRoot } from './package-tools.mjs';

const [scriptName, ...args] = process.argv.slice(2);

if (!scriptName) {
	console.error('Usage: node ./scripts/run-package-script.mjs <script> [...args]');
	process.exit(1);
}

const result = spawnSync('npm', ['run', scriptName, '--', ...args], {
	stdio: 'inherit',
	cwd: packageRoot,
	env: { ...process.env },
});

if (result.status !== 0) {
	process.exit(result.status ?? 1);
}
