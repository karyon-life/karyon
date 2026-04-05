import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, extname, join } from 'node:path';
import { cleanupDir, createTempDir, packageInfo, packageJsonFor, run, changedWorkspacePackages } from './workspace-lib.mjs';

const cliArgs = new Set(process.argv.slice(2));
const verifyChangedOnly = cliArgs.has('--changed');
const changed = verifyChangedOnly ? changedWorkspacePackages() : ['sdk', 'core'];
const packagesToVerify = changed.filter((key) => ['sdk', 'core'].includes(key));
const textExtensions = new Set(['.js', '.mjs', '.cjs', '.d.ts', '.ts', '.json', '.md', '.astro']);
const npmCacheRoot = createTempDir('treeseed-release-cache-');
const forbiddenPatterns = [
	/['"`]file:[^'"`\n]+['"`]/,
	/['"`]workspace:[^'"`\n]+['"`]/,
	/['"`][^'"`\n]*\.\.\/sdk\/src\/[^'"`\n]*['"`]/,
	/['"`][^'"`\n]*\/packages\/sdk\/[^'"`\n]*['"`]/,
	/['"`][^'"`\n]*\/packages\/core\/[^'"`\n]*['"`]/,
	/['"`][^'"`\n]*@treeseed\/sdk\/src\/[^'"`\n]*['"`]/,
];

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

function packPackage(key) {
	const pkg = packageInfo(key);
	const packageJson = packageJsonFor(key);
	run('npm', ['pack', '--ignore-scripts'], {
		cwd: pkg.dir,
		env: {
			npm_config_cache: npmCacheRoot,
			NPM_CONFIG_CACHE: npmCacheRoot,
		},
	});
	return resolve(
		pkg.dir,
		`${packageJson.name.replace(/^@/, '').replaceAll('/', '-')}-${packageJson.version}.tgz`,
	);
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
			env: {
				npm_config_cache: npmCacheRoot,
				NPM_CONFIG_CACHE: npmCacheRoot,
			},
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
	for (const key of packagesToVerify) {
		const pkg = packageInfo(key);
		verifyManifest(key);
		run('npm', ['run', 'build:dist'], { cwd: pkg.dir });
		scanDirectory(resolve(pkg.dir, 'dist'), `${pkg.name}:dist`);
		const tarballPath = packPackage(key);
		tarballs.set(key, tarballPath);
		scanTarball(tarballPath, `${pkg.name}:tarball`);
	}

	if (packagesToVerify.includes('core')) {
		run('npm', ['run', 'test:scaffold'], { cwd: packageInfo('core').dir });
	} else if (packagesToVerify.includes('sdk')) {
		sdkInstallSmoke(tarballs.get('sdk'));
	}

	console.log(`Release verification passed for: ${packagesToVerify.join(', ')}`);
} finally {
	for (const tarballPath of tarballs.values()) {
		if (existsSync(tarballPath)) {
			cleanupDir(tarballPath);
		}
	}
	cleanupDir(npmCacheRoot);
}
