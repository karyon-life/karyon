import { readdirSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';

const root = resolve(import.meta.dirname);
const packageRoots = ['cli', 'core', 'sdk', 'agent'].map((name) => resolve(root, name));
const allowedDts = new Set([
	'core/src/types/astro-build.d.ts',
	'core/src/types/cloudflare-sockets.d.ts',
]);

function walk(dir: string, files: string[] = []) {
	for (const entry of readdirSync(dir, { withFileTypes: true })) {
		if (entry.name === 'dist' || entry.name === 'node_modules' || entry.name === '.astro') continue;
		const fullPath = join(dir, entry.name);
		if (entry.isDirectory()) {
			walk(fullPath, files);
			continue;
		}
		files.push(fullPath);
	}
	return files;
}

const failures: string[] = [];

for (const packageRoot of packageRoots) {
	for (const file of walk(packageRoot)) {
		const rel = relative(root, file).replaceAll('\\', '/');
		if (rel.endsWith('.mjs')) {
			if (!rel.endsWith('.test.mjs')) {
				failures.push(`Unexpected owned .mjs source: ${rel}`);
			}
			continue;
		}
		if (rel.endsWith('.d.ts') && rel.includes('/src/')) {
			if (!allowedDts.has(rel)) {
				failures.push(`Unexpected handwritten source .d.ts: ${rel}`);
			}
		}
	}
}

if (failures.length > 0) {
	console.error('Owned source audit failed:\n');
	for (const failure of failures) {
		console.error(`- ${failure}`);
	}
	process.exit(1);
}

console.log('Owned source audit passed.');
