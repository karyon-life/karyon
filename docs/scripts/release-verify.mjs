import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, extname, join } from 'node:path';
import { homedir } from 'node:os';
import { cleanupDir, packageInfo, packageJsonFor, run, changedWorkspacePackages } from './workspace-lib.mjs';

const cliArgs = new Set(process.argv.slice(2));
const verifyChangedOnly = cliArgs.has('--changed');
const fullSmoke = cliArgs.has('--full-smoke') || process.env.TREESEED_RELEASE_FULL_SMOKE === '1';
const changed = verifyChangedOnly ? changedWorkspacePackages() : ['sdk', 'core'];
const packagesToVerify = changed.filter((key) => ['sdk', 'core'].includes(key));
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
	/['"`][^'"`\n]*\.\.\/sdk\/src\/[^'"`\n]*['"`]/,
	/['"`][^'"`\n]*\/packages\/sdk\/[^'"`\n]*['"`]/,
	/['"`][^'"`\n]*\/packages\/core\/[^'"`\n]*['"`]/,
	/['"`][^'"`\n]*@treeseed\/sdk\/src\/[^'"`\n]*['"`]/,
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

function packPackage(key) {
	const pkg = packageInfo(key);
	const packageJson = packageJsonFor(key);
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
		|| `${packageJson.name.replace(/^@/, '').replaceAll('/', '-')}-${packageJson.version}.tgz`;
	return resolve(pkg.dir, filename);
}

function scanTarball(tarballPath, label) {
	const files = run('tar', ['-tf', tarballPath], { capture: true })
		.split('\n')
		.map((line) => line.trim())
		.filter(Boolean);

	for (const filePath of files) {
		if (!textExtensions.has(extname(filePath))) {
			continue;
		}
		const contents = run('tar', ['-xOf', tarballPath, filePath], { capture: true });
		assertNoForbiddenRefsInText(`${label}:${filePath}`, contents);
	}
}

function verifyManifest(key) {
	const packageJson = packageJsonFor(key);
	for (const [dep, value] of Object.entries(packageJson.dependencies ?? {})) {
		if (!dep.startsWith('@treeseed/')) {
			continue;
		}
		if (String(value).startsWith('file:') || String(value).startsWith('workspace:')) {
			throw new Error(`${packageJson.name} dependency ${dep} must not use local-only specifier "${value}".`);
		}
	}
}

function sdkInstallSmoke(sdkTarballPath) {
	const tempRoot = createTempDir('treeseed-sdk-release-');
	try {
		writeFileSync(
			resolve(tempRoot, 'package.json'),
			`${JSON.stringify(
				{
					name: 'treeseed-sdk-release-smoke',
					private: true,
					type: 'module',
					dependencies: {
						'@treeseed/sdk': sdkTarballPath,
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
				"const sdk = await import('@treeseed/sdk'); if (!sdk.AgentSdk) throw new Error('AgentSdk export missing');",
			],
			{ cwd: tempRoot },
		);
	} finally {
		cleanupDir(tempRoot);
	}
}

if (packagesToVerify.length === 0) {
	console.log('No changed workspace packages to verify.');
	process.exit(0);
}

const tarballs = new Map();

try {
	logStep(
		`verifying ${packagesToVerify.join(', ')} with ${fullSmoke ? 'full' : 'fast'} smoke checks (timeout ${Math.round(smokeTimeoutMs / 1000)}s, cache ${npmCacheRoot})`,
	);
	for (const key of packagesToVerify) {
		const pkg = packageInfo(key);
		await withTiming(`${pkg.name} manifest verification`, async () => {
			verifyManifest(key);
		});
		await withTiming(`${pkg.name} build`, async () => {
			run('npm', ['run', 'build:dist'], { cwd: pkg.dir, timeoutMs: smokeTimeoutMs });
		});
		await withTiming(`${pkg.name} dist leak scan`, async () => {
			scanDirectory(resolve(pkg.dir, 'dist'), `${pkg.name}:dist`);
		});
		const tarballPath = await withTiming(`${pkg.name} pack`, async () => packPackage(key));
		tarballs.set(key, tarballPath);
		await withTiming(`${pkg.name} tarball leak scan`, async () => {
			scanTarball(tarballPath, `${pkg.name}:tarball`);
		});
	}

	if (packagesToVerify.includes('core')) {
		await withTiming(`@treeseed/core scaffold smoke (${fullSmoke ? 'build+deploy' : 'build'})`, async () => {
			run(
				process.execPath,
				[resolve(packageInfo('core').dir, 'scripts', 'test-scaffold.mjs')],
				{
					cwd: packageInfo('core').dir,
					timeoutMs: smokeTimeoutMs,
					env: {
						TREESEED_SCAFFOLD_CORE_TARBALL: tarballs.get('core'),
						TREESEED_SCAFFOLD_SDK_TARBALL: tarballs.get('sdk'),
						TREESEED_SCAFFOLD_NPM_CACHE_DIR: npmCacheRoot,
						TREESEED_SCAFFOLD_CHECKS: fullSmoke ? 'build,deploy' : 'build',
					},
				},
			);
		});
	} else if (packagesToVerify.includes('sdk')) {
		await withTiming('@treeseed/sdk install smoke', async () => {
			sdkInstallSmoke(tarballs.get('sdk'));
		});
	}

	console.log(`Release verification passed for: ${packagesToVerify.join(', ')}`);
} finally {
	printSummary();
	for (const tarballPath of tarballs.values()) {
		if (existsSync(tarballPath)) {
			cleanupDir(tarballPath);
		}
	}
}
