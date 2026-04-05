import { spawn, spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import {
	fixtureMigrationsRoot,
	fixtureRoot,
	fixtureWranglerConfig,
	packageRoot,
} from './paths.mjs';

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

export function runNodeScript(scriptRelativePath, args = [], options = {}) {
	return runStep(process.execPath, [resolve(packageRoot, scriptRelativePath), ...args], {
		...options,
		cwd: options.cwd ?? packageRoot,
	});
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
	runNodeScript(
		'./scripts/sync-dev-vars.mjs',
		overrideEntries.map(([key, value]) => `${key}=${value}`),
		{ cwd: fixtureRoot },
	);
}

export function runLocalD1Migration(persistTo) {
	for (const file of [
		resolve(fixtureMigrationsRoot, '0001_subscribers.sql'),
		resolve(fixtureMigrationsRoot, '0002_agent_runtime.sql'),
		resolve(fixtureMigrationsRoot, '0003_agent_run_trace.sql'),
	]) {
		const args = [
			'd1',
			'execute',
			'karyon-docs-subscribers',
			'--local',
			'--config',
			fixtureWranglerConfig,
			`--file=${file}`,
		];

		if (persistTo) {
			args.push('--persist-to', persistTo);
		}

		runStep('wrangler', args, { cwd: fixtureRoot });
	}
}

export function prepareCloudflareLocalRuntime({ envOverrides = {}, persistTo } = {}) {
	const mergedEnvOverrides = {
		DOCS_MAILPIT_SMTP_HOST: '127.0.0.1',
		DOCS_MAILPIT_SMTP_PORT: '1125',
		...envOverrides,
	};

	runNodeScript('./scripts/patch-starlight-content-path.mjs');
	runNodeScript('./scripts/aggregate-book.mjs');
	runNodeScript('./scripts/ensure-mailpit.mjs');
	syncDevVars({
		DOCS_LOCAL_DEV_MODE: 'cloudflare',
		...mergedEnvOverrides,
	});
	runLocalD1Migration(persistTo);
	runStep('npx', ['astro', 'build', '--root', fixtureRoot], {
		env: {
			DOCS_LOCAL_DEV_MODE: 'cloudflare',
			...mergedEnvOverrides,
		},
		cwd: packageRoot,
	});
}

export function startWranglerDev(args = [], options = {}) {
	return spawnProcess(
		'wrangler',
		['dev', '--local', '--config', fixtureWranglerConfig, ...args],
		{
			...options,
			cwd: options.cwd ?? fixtureRoot,
		},
	);
}
