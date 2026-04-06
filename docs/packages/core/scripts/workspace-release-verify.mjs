import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, extname, join } from 'node:path';
import { homedir } from 'node:os';
import {
	cleanupDir,
	createTempDir,
	publishableWorkspacePackages,
	run,
	changedWorkspacePackages,
} from './workspace-tools.mjs';

const cliArgs = new Set(process.argv.slice(2));
const verifyChangedOnly = cliArgs.has('--changed');
const fullSmoke = cliArgs.has('--full-smoke') || process.env.TREESEED_RELEASE_FULL_SMOKE === '1';
const publishablePackages = publishableWorkspacePackages();
const packagesToVerify = verifyChangedOnly
	? changedWorkspacePackages({ packages: publishablePackages, includeDependents: true })
	: publishablePackages;
const textExtensions = new Set(['.js', '.mjs', '.cjs', '.d.ts', '.ts', '.json', '.astro']);
const npmCacheRoot = resolve(
	process.env.TREESEED_RELEASE_NPM_CACHE_DIR
		?? process.env.npm_config_cache
		?? process.env.NPM_CONFIG_CACHE
		?? resolve(homedir(), '.npm'),
);
const smokeTimeoutMs = Number(process.env.TREESEED_RELEASE_SMOKE_TIMEOUT_MS ?? 600000);
const timings = [];
const forbiddenPatterns = [
	/['"`]file:[^'"`\n]+['"`]/,
	/['"`]workspace:[^'"`\n]+['"`]/,
	/['"`](?:\.\.\/|\.\/)[^'"`\n]*src\/[^'"`\n]*\.(?:[cm]?js|ts|tsx|json|astro|css)['"`]/,
	/['"`][^'"`\n]*\/packages\/[^'"`\n]*\/src\/[^'"`\n]*['"`]/,
	/['"`][^'"`\n]*@treeseed\/[^'"`\n]*\/src\/[^'"`\n]*['"`]/,
];

function nowLabel() {
	return new Date().toISOString();
}

function logStep(message) {
	console.log(`[release-verify ${nowLabel()}] ${message}`);
}

async function withTiming(label, action) {
	const startedAt = Date.now();
	logStep(`${label} started`);
	try {
		const result = await action();
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

	console.log('[release-verify] Stage summary');
	for (const entry of timings) {
		console.log(
			`[release-verify] ${entry.status === 'completed' ? 'ok  ' : 'fail'} ${entry.label} (${(entry.durationMs / 1000).toFixed(1)}s)`,
		);
	}
}

function walkFiles(root) {
	const files = [];
	if (!existsSync(root)) {
		return files;
	}

	for (const entry of readdirSync(root, { withFileTypes: true })) {
		const fullPath = join(root, entry.name);
		if (entry.isDirectory()) {
			files.push(...walkFiles(fullPath));
			continue;
		}
		files.push(fullPath);
	}
	return files;
}

function assertNoForbiddenRefsInText(label, source) {
	for (const pattern of forbiddenPatterns) {
		if (pattern.test(source)) {
			throw new Error(`${label} contains forbidden publish reference matching ${pattern}.`);
		}
	}
}

function scanDirectory(root, label) {
	for (const filePath of walkFiles(root)) {
		if (!textExtensions.has(extname(filePath))) {
			continue;
		}
		assertNoForbiddenRefsInText(`${label}:${filePath}`, readFileSync(filePath, 'utf8'));
	}
}

function cacheEnv() {
	return {
		npm_config_cache: npmCacheRoot,
		NPM_CONFIG_CACHE: npmCacheRoot,
		npm_config_prefer_offline: 'true',
		npm_config_audit: 'false',
		npm_config_fund: 'false',
		npm_config_fetch_retries: process.env.TREESEED_RELEASE_FETCH_RETRIES ?? '1',
		npm_config_fetch_retry_mintimeout: process.env.TREESEED_RELEASE_FETCH_RETRY_MIN_TIMEOUT_MS ?? '1000',
		npm_config_fetch_retry_maxtimeout: process.env.TREESEED_RELEASE_FETCH_RETRY_MAX_TIMEOUT_MS ?? '5000',
		npm_config_fetch_timeout: process.env.TREESEED_RELEASE_FETCH_TIMEOUT_MS ?? '30000',
	};
}

function packPackage(pkg) {
	const output = run('npm', ['pack', '--silent', '--ignore-scripts'], {
		cwd: pkg.dir,
		capture: true,
		env: cacheEnv(),
	});
	const filename = output
		.split('\n')
		.map((line) => line.trim())
		.filter(Boolean)
		.at(-1)
		|| `${pkg.name.replace(/^@/, '').replaceAll('/', '-')}-${pkg.packageJson.version}.tgz`;
	return resolve(pkg.dir, filename);
}

function scanTarball(tarballPath, label) {
	const files = run('tar', ['-tf', tarballPath], { capture: true })
		.split('\n')
		.map((line) => line.trim())
		.filter(Boolean);

	for (const filePath of files) {
		if (filePath === 'package/package.json') {
			continue;
		}
		if (!textExtensions.has(extname(filePath))) {
			continue;
		}
		const contents = run('tar', ['-xOf', tarballPath, filePath], { capture: true });
		assertNoForbiddenRefsInText(`${label}:${filePath}`, contents);
	}
}

function verifyManifest(pkg) {
	for (const [dep, value] of Object.entries(pkg.packageJson.dependencies ?? {})) {
		if (!dep.startsWith('@treeseed/')) {
			continue;
		}
		if (String(value).startsWith('file:') || String(value).startsWith('workspace:')) {
			throw new Error(`${pkg.name} dependency ${dep} must not use local-only specifier "${value}".`);
		}
	}
}

function tarballEnv(tarballs) {
	return {
		TREESEED_WORKSPACE_TARBALLS: JSON.stringify(Object.fromEntries(tarballs)),
		...(tarballs.get('@treeseed/core') ? { TREESEED_SCAFFOLD_CORE_TARBALL: tarballs.get('@treeseed/core') } : {}),
		...(tarballs.get('@treeseed/sdk') ? { TREESEED_SCAFFOLD_SDK_TARBALL: tarballs.get('@treeseed/sdk') } : {}),
	};
}

function genericInstallSmoke(pkg, tarballPath) {
	const tempRoot = createTempDir('treeseed-package-release-');
	try {
		writeFileSync(
			resolve(tempRoot, 'package.json'),
			`${JSON.stringify(
				{
					name: 'treeseed-package-release-smoke',
					private: true,
					type: 'module',
					dependencies: {
						[pkg.name]: tarballPath,
					},
				},
				null,
				2,
			)}\n`,
			'utf8',
		);
		run('npm', ['install', '--prefer-offline', '--no-audit', '--no-fund'], {
			cwd: tempRoot,
			env: cacheEnv(),
		});
		run(
			process.execPath,
			[
				'--input-type=module',
				'-e',
				`await import(${JSON.stringify(pkg.name)});`,
			],
			{ cwd: tempRoot },
		);
	} finally {
		cleanupDir(tempRoot);
	}
}

async function smokePackage(pkg, tarballs) {
	const env = {
		...cacheEnv(),
		...tarballEnv(tarballs),
		TREESEED_SCAFFOLD_NPM_CACHE_DIR: npmCacheRoot,
		TREESEED_SCAFFOLD_CHECKS: fullSmoke ? 'build,deploy' : 'build',
	};

	if (typeof pkg.packageJson.scripts?.['test:scaffold'] === 'string') {
		run('npm', ['run', 'test:scaffold'], {
			cwd: pkg.dir,
			timeoutMs: smokeTimeoutMs,
			env,
		});
		return;
	}

	if (typeof pkg.packageJson.scripts?.['test:smoke'] === 'string') {
		run('npm', ['run', 'test:smoke'], {
			cwd: pkg.dir,
			timeoutMs: smokeTimeoutMs,
			env,
		});
		return;
	}

	genericInstallSmoke(pkg, tarballs.get(pkg.name));
}

if (packagesToVerify.length === 0) {
	console.log('No changed workspace packages to verify.');
	process.exit(0);
}

const tarballs = new Map();

try {
	logStep(
		`verifying ${packagesToVerify.map((pkg) => pkg.name).join(', ')} with ${fullSmoke ? 'full' : 'fast'} smoke checks (timeout ${Math.round(smokeTimeoutMs / 1000)}s, cache ${npmCacheRoot})`,
	);
	for (const pkg of packagesToVerify) {
		await withTiming(`${pkg.name} manifest verification`, async () => {
			verifyManifest(pkg);
		});
		await withTiming(`${pkg.name} build`, async () => {
			run('npm', ['run', 'build:dist'], { cwd: pkg.dir, timeoutMs: smokeTimeoutMs });
		});
		await withTiming(`${pkg.name} dist leak scan`, async () => {
			scanDirectory(resolve(pkg.dir, 'dist'), `${pkg.name}:dist`);
		});
		const tarballPath = await withTiming(`${pkg.name} pack`, async () => packPackage(pkg));
		tarballs.set(pkg.name, tarballPath);
		await withTiming(`${pkg.name} tarball leak scan`, async () => {
			scanTarball(tarballPath, `${pkg.name}:tarball`);
		});
	}

	for (const pkg of packagesToVerify) {
		await withTiming(
			`${pkg.name} smoke (${typeof pkg.packageJson.scripts?.['test:scaffold'] === 'string'
				? (fullSmoke ? 'build+deploy' : 'build')
				: typeof pkg.packageJson.scripts?.['test:smoke'] === 'string'
					? 'package smoke'
					: 'install'
			})`,
			async () => {
				await smokePackage(pkg, tarballs);
			},
		);
	}

	console.log(`Release verification passed for: ${packagesToVerify.map((pkg) => pkg.name).join(', ')}`);
} finally {
	printSummary();
	for (const tarballPath of tarballs.values()) {
		if (existsSync(tarballPath)) {
			cleanupDir(tarballPath);
		}
	}
}
