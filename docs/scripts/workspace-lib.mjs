import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

export const docsRoot = process.cwd();
export const workspacePackages = [
	{
		name: '@treeseed/sdk',
		key: 'sdk',
		dir: resolve(docsRoot, 'packages', 'sdk'),
	},
	{
		name: '@treeseed/core',
		key: 'core',
		dir: resolve(docsRoot, 'packages', 'core'),
	},
];

export function packageInfo(key) {
	const pkg = workspacePackages.find((entry) => entry.key === key);
	if (!pkg) {
		throw new Error(`Unknown workspace package "${key}".`);
	}
	return pkg;
}

export function readJson(filePath) {
	return JSON.parse(readFileSync(filePath, 'utf8'));
}

export function run(command, args, options = {}) {
	const result = spawnSync(command, args, {
		cwd: options.cwd ?? docsRoot,
		env: { ...process.env, ...(options.env ?? {}) },
		stdio: options.capture ? 'pipe' : 'inherit',
		encoding: 'utf8',
		timeout: options.timeoutMs,
	});

	if (result.status !== 0) {
		const message =
			(result.error?.message ? `${result.error.message}\n` : '')
			+ (
				result.stderr?.trim()
				|| result.stdout?.trim()
				|| `${command} ${args.join(' ')} failed`
			);
		throw new Error(message);
	}

	return (result.stdout ?? '').trim();
}

export function packageJsonFor(key) {
	const pkg = packageInfo(key);
	return readJson(resolve(pkg.dir, 'package.json'));
}

export function changedWorkspacePackages(baseRef = process.env.TREESEED_RELEASE_BASE_REF ?? 'HEAD^') {
	const changedFiles = new Set();
	for (const args of [
		['diff', '--name-only', baseRef, 'HEAD'],
		['diff', '--name-only'],
		['diff', '--name-only', '--cached'],
		['ls-files', '--others', '--exclude-standard'],
	]) {
		const output = run('git', args, { capture: true });
		for (const line of output.split('\n').map((entry) => entry.trim()).filter(Boolean)) {
			changedFiles.add(line);
		}
	}

	const changed = new Set();
	for (const pkg of workspacePackages) {
		const fragment = `packages/${pkg.key}/`;
		if ([...changedFiles].some((file) => file.startsWith(fragment))) {
			changed.add(pkg.key);
		}
	}

	return [...changed];
}

export function createTempDir(prefix) {
	return mkdtempSync(join(tmpdir(), prefix));
}

export function cleanupDir(dirPath) {
	if (dirPath && existsSync(dirPath)) {
		rmSync(dirPath, { recursive: true, force: true });
	}
}
