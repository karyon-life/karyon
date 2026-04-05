#!/usr/bin/env node

import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { packageRoot, packageScriptPath } from './package-tools.mjs';

const npmCacheDir = resolve(packageRoot, '.local', 'scaffold-npm-cache');
const packageJson = JSON.parse(readFileSync(resolve(packageRoot, 'package.json'), 'utf8'));
const sdkPackageRoot = resolve(packageRoot, '..', 'sdk');
const sdkPackageJson = JSON.parse(readFileSync(resolve(sdkPackageRoot, 'package.json'), 'utf8'));

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
	runStep('npm', ['run', 'build:dist'], { cwd: root });
	runStep('npm', ['pack', '--ignore-scripts', '--cache', npmCacheDir], {
		cwd: root,
		env: {
			npm_config_cache: npmCacheDir,
			NPM_CONFIG_CACHE: npmCacheDir,
		},
	});
	const filename = `${pkg.name.replace(/^@/, '').replaceAll('/', '-')}-${pkg.version}.tgz`;
	return resolve(root, filename);
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
	runStep('npm', ['run', 'build'], { cwd: siteRoot });
	runStep('npm', ['run', 'deploy', '--', '--dry-run'], { cwd: siteRoot });
}

const siteRoot = createTempSiteRoot();
let tarballPath;
let sdkTarballPath;

try {
	resetNpmCache();
	sdkTarballPath = createTarball(sdkPackageRoot, sdkPackageJson);
	tarballPath = createTarball(packageRoot, packageJson);
	scaffoldSite(siteRoot);
	rewriteScaffoldDependency(siteRoot, tarballPath, sdkTarballPath);
	installScaffold(siteRoot);
	runScaffoldChecks(siteRoot);
	console.log(`Scaffold smoke test passed in ${dirname(siteRoot) ? siteRoot : '.'}`);
} finally {
	rmSync(siteRoot, { recursive: true, force: true });
	if (sdkTarballPath) {
		rmSync(sdkTarballPath, { force: true });
	}
	if (tarballPath) {
		rmSync(tarballPath, { force: true });
	}
	resetNpmCache();
}
