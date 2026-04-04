import { spawn, spawnSync } from 'node:child_process';

function mergeEnv(extraEnv = {}) {
	return { ...process.env, ...extraEnv };
}

export function runStep(command, args, options = {}) {
	const result = spawnSync(command, args, {
		stdio: 'inherit',
		shell: process.platform === 'win32',
		env: mergeEnv(options.env),
		cwd: options.cwd ?? process.cwd(),
	});

	if (result.status !== 0) {
		process.exit(result.status ?? 1);
	}
}

export function spawnProcess(command, args, options = {}) {
	return spawn(command, args, {
		stdio: options.stdio ?? 'inherit',
		shell: process.platform === 'win32',
		env: mergeEnv(options.env),
		cwd: options.cwd ?? process.cwd(),
	});
}

export function syncDevVars(overrides = {}) {
	const overrideEntries = Object.entries(overrides);
	const args = ['run', 'sync:devvars'];

	if (overrideEntries.length) {
		args.push('--', ...overrideEntries.map(([key, value]) => `${key}=${value}`));
	}

	runStep('npm', args);
}

export function runLocalD1Migration(persistTo) {
	const args = [
		'd1',
		'execute',
		'karyon-docs-subscribers',
		'--local',
		'--file=./migrations/0001_subscribers.sql',
	];

	if (persistTo) {
		args.push('--persist-to', persistTo);
	}

	runStep('wrangler', args);
}

export function prepareCloudflareLocalRuntime({ envOverrides = {}, persistTo } = {}) {
	runStep('npm', ['run', 'mailpit:up']);
	syncDevVars({
		DOCS_LOCAL_DEV_MODE: 'cloudflare',
		...envOverrides,
	});
	runLocalD1Migration(persistTo);
	runStep('npm', ['run', 'build'], {
		env: {
			DOCS_LOCAL_DEV_MODE: 'cloudflare',
			...envOverrides,
		},
	});
}

export function startWranglerDev(args = [], options = {}) {
	return spawnProcess('wrangler', ['dev', '--local', ...args], options);
}
