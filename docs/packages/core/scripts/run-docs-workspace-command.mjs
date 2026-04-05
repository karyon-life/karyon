import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const packageRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
const docsRoot = resolve(packageRoot, '../..');

const [command, ...rest] = process.argv.slice(2);

if (!command) {
	console.error('Usage: node ./scripts/run-docs-workspace-command.mjs <install|ci|script> [...args]');
	process.exit(1);
}

const npmArgs =
	command === 'install' || command === 'ci'
		? [command, ...rest]
		: ['run', command, ...(rest.length ? ['--', ...rest] : [])];

const result = spawnSync('npm', npmArgs, {
	cwd: docsRoot,
	stdio: 'inherit',
	env: process.env,
});

if (result.error) {
	console.error(result.error.message);
	process.exit(1);
}

process.exit(result.status ?? 1);
