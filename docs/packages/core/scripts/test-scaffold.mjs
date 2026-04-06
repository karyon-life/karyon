#!/usr/bin/env node

import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { packageRoot, packageScriptPath } from './package-tools.mjs';

const npmCacheDir = process.env.TREESEED_SCAFFOLD_NPM_CACHE_DIR
	? resolve(process.env.TREESEED_SCAFFOLD_NPM_CACHE_DIR)
	: resolve(
		process.env.npm_config_cache
			?? process.env.NPM_CONFIG_CACHE
			?? resolve(homedir(), '.npm'),
	);
const packageJson = JSON.parse(readFileSync(resolve(packageRoot, 'package.json'), 'utf8'));
const sdkPackageRoot = resolve(packageRoot, '..', 'sdk');
const sdkPackageJson = JSON.parse(readFileSync(resolve(sdkPackageRoot, 'package.json'), 'utf8'));
const workspaceTarballs = (() => {
	try {
		return JSON.parse(process.env.TREESEED_WORKSPACE_TARBALLS ?? '{}');
	} catch {
		return {};
	}
})();
const externalCoreTarball = process.env.TREESEED_SCAFFOLD_CORE_TARBALL
	? resolve(process.env.TREESEED_SCAFFOLD_CORE_TARBALL)
	: typeof workspaceTarballs['@treeseed/core'] === 'string'
		? resolve(workspaceTarballs['@treeseed/core'])
	: null;
const externalSdkTarball = process.env.TREESEED_SCAFFOLD_SDK_TARBALL
	? resolve(process.env.TREESEED_SCAFFOLD_SDK_TARBALL)
	: typeof workspaceTarballs['@treeseed/sdk'] === 'string'
		? resolve(workspaceTarballs['@treeseed/sdk'])
	: null;
const reusesExternalTarballs = Boolean(externalCoreTarball || externalSdkTarball);
const scaffoldChecks = new Set(
	(process.env.TREESEED_SCAFFOLD_CHECKS ?? 'build,deploy')
		.split(',')
		.map((value) => value.trim())
		.filter(Boolean),
);
const timings = [];
const resetScaffoldCache = process.env.TREESEED_SCAFFOLD_RESET_CACHE === '1';

function logStep(message) {
	console.log(`[treeseed:test-scaffold] ${message}`);
}

function withTiming(label, action) {
	const startedAt = Date.now();
	logStep(`${label} started`);
	try {
		const result = action();
		const durationMs = Date.now() - startedAt;
		timings.push({ label, durationMs, status: 'completed' });
		logStep(`${label} completed in ${(durationMs / 1000).toFixed(1)}s`);
		return result;
	} catch (error) {
		const durationMs = Date.now() - startedAt;
		timings.push({ label, durationMs, status: 'failed' });
		logStep(`${label} failed in ${(durationMs / 1000).toFixed(1)}s`);
		throw error;
	}
}

function printSummary() {
	if (timings.length === 0) {
		return;
	}

	console.log('[treeseed:test-scaffold] Stage summary');
	for (const entry of timings) {
		console.log(
			`[treeseed:test-scaffold] ${entry.status === 'completed' ? 'ok  ' : 'fail'} ${entry.label} (${(entry.durationMs / 1000).toFixed(1)}s)`,
		);
	}
}

function resetNpmCache() {
	rmSync(npmCacheDir, { recursive: true, force: true });
}

function runStep(command, args, { cwd = packageRoot, env = {}, capture = false } = {}) {
	const result = spawnSync(command, args, {
		cwd,
		env: { ...process.env, ...env },
		stdio: capture ? 'pipe' : 'inherit',
		encoding: 'utf8',
	});

	if (result.status !== 0) {
		const message = capture ? (result.stderr?.trim() || result.stdout?.trim() || `${command} ${args.join(' ')} failed`) : `${command} ${args.join(' ')} failed`;
		throw new Error(message);
	}

	return result;
}

function createTempSiteRoot() {
	return mkdtempSync(join(tmpdir(), 'treeseed-scaffold-'));
}

function rewriteScaffoldDependency(siteRoot, tarballPath, sdkTarballPath) {
	const packageJsonPath = resolve(siteRoot, 'package.json');
	const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'));
	packageJson.dependencies = packageJson.dependencies ?? {};
	packageJson.dependencies['@treeseed/core'] = tarballPath;
	packageJson.dependencies['@treeseed/sdk'] = sdkTarballPath;
	writeFileSync(packageJsonPath, `${JSON.stringify(packageJson, null, 2)}\n`, 'utf8');
}

function createTarball(root, pkg) {
	return withTiming(`${pkg.name} build+pack`, () => {
		runStep('npm', ['run', 'build:dist'], { cwd: root });
		const output = runStep('npm', ['pack', '--silent', '--ignore-scripts', '--cache', npmCacheDir], {
			cwd: root,
			capture: true,
			env: {
				npm_config_cache: npmCacheDir,
				NPM_CONFIG_CACHE: npmCacheDir,
			},
		});
		const filename = output.stdout
			.split('\n')
			.map((line) => line.trim())
			.filter(Boolean)
			.at(-1)
			|| `${pkg.name.replace(/^@/, '').replaceAll('/', '-')}-${pkg.version}.tgz`;
		return resolve(root, filename);
	});
}

function scaffoldSite(siteRoot) {
	runStep(process.execPath, [packageScriptPath('scaffold-site'), siteRoot, '--name', 'Smoke Site', '--site-url', 'https://smoke.example.com', '--contact-email', 'hello@example.com']);
}

function installScaffold(siteRoot) {
	runStep('npm', ['install', '--cache', npmCacheDir, '--prefer-offline', '--no-audit', '--no-fund'], {
		cwd: siteRoot,
		env: {
			npm_config_cache: npmCacheDir,
			NPM_CONFIG_CACHE: npmCacheDir,
			npm_config_prefer_offline: 'true',
			npm_config_audit: 'false',
			npm_config_fund: 'false',
		},
	});
}

function runScaffoldChecks(siteRoot) {
	if (scaffoldChecks.has('build')) {
		withTiming('scaffold build', () => {
			runStep('npm', ['run', 'build'], { cwd: siteRoot });
		});
	}
	if (scaffoldChecks.has('deploy')) {
		withTiming('scaffold deploy dry-run', () => {
			runStep('npm', ['run', 'deploy', '--', '--dry-run'], { cwd: siteRoot });
		});
	}
}

const siteRoot = createTempSiteRoot();
let tarballPath = externalCoreTarball;
let sdkTarballPath = externalSdkTarball;

try {
	if (!reusesExternalTarballs && resetScaffoldCache) {
		logStep(`resetting npm cache at ${npmCacheDir}`);
		resetNpmCache();
	}
	if (!sdkTarballPath) {
		logStep('building and packing @treeseed/sdk');
		sdkTarballPath = createTarball(sdkPackageRoot, sdkPackageJson);
	} else {
		logStep(`reusing provided @treeseed/sdk tarball: ${sdkTarballPath}`);
	}
	if (!tarballPath) {
		logStep('building and packing @treeseed/core');
		tarballPath = createTarball(packageRoot, packageJson);
	} else {
		logStep(`reusing provided @treeseed/core tarball: ${tarballPath}`);
	}
	logStep(`scaffolding temporary tenant at ${siteRoot}`);
	withTiming('scaffold tenant generation', () => {
		scaffoldSite(siteRoot);
	});
	rewriteScaffoldDependency(siteRoot, tarballPath, sdkTarballPath);
	logStep(`installing scaffolded tenant dependencies with checks: ${[...scaffoldChecks].join(', ') || 'none'}`);
	withTiming('scaffold dependency install', () => {
		installScaffold(siteRoot);
	});
	logStep('running scaffold smoke checks');
	runScaffoldChecks(siteRoot);
	console.log(`Scaffold smoke test passed in ${dirname(siteRoot) ? siteRoot : '.'}`);
} finally {
	printSummary();
	rmSync(siteRoot, { recursive: true, force: true });
	if (sdkTarballPath && !externalSdkTarball) {
		rmSync(sdkTarballPath, { force: true });
	}
	if (tarballPath && !externalCoreTarball) {
		rmSync(tarballPath, { force: true });
	}
	if (!reusesExternalTarballs && resetScaffoldCache) {
		resetNpmCache();
	}
}
