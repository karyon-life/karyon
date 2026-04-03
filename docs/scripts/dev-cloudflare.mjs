import { spawnSync } from 'node:child_process';

const steps = [
	['npm', ['run', 'mailpit:up']],
	['npm', ['run', 'sync:devvars', '--', 'cloudflare']],
	['npm', ['run', 'd1:migrate:local']],
	['npm', ['run', 'build'], { env: { ...process.env, DOCS_LOCAL_DEV_MODE: 'cloudflare' } }],
	['wrangler', ['dev', '--local']],
];

for (const [command, args, options = {}] of steps) {
	const result = spawnSync(command, args, {
		stdio: 'inherit',
		shell: process.platform === 'win32',
		env: options.env ?? process.env,
	});

	if (result.status !== 0) {
		process.exit(result.status ?? 1);
	}
}
