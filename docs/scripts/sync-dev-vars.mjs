import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const envFilePath = resolve(process.cwd(), '.env.local');
const outputPath = resolve(process.cwd(), '.dev.vars');
const modeOverride = process.argv[2];

function parseEnvFile(contents) {
	return contents
		.split(/\r?\n/)
		.map((line) => line.trim())
		.filter((line) => line && !line.startsWith('#'))
		.reduce((acc, line) => {
			const separatorIndex = line.indexOf('=');
			if (separatorIndex === -1) return acc;
			acc[line.slice(0, separatorIndex).trim()] = line.slice(separatorIndex + 1);
			return acc;
		}, {});
}

let envMap = {};

try {
	envMap = parseEnvFile(readFileSync(envFilePath, 'utf8'));
} catch {
	console.error('Missing docs/.env.local. Copy docs/.env.local.example to docs/.env.local first.');
	process.exit(1);
}

if (modeOverride) {
	envMap.DOCS_LOCAL_DEV_MODE = modeOverride;
}

const docsEntries = Object.entries(envMap)
	.filter(([key]) => key.startsWith('DOCS_'))
	.map(([key, value]) => `${key}=${value}`);

mkdirSync(resolve(process.cwd(), '.local'), { recursive: true });
writeFileSync(outputPath, `${docsEntries.join('\n')}\n`, 'utf8');
console.log(`Wrote ${outputPath}`);
