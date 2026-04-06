import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const envFilePath = resolve(process.cwd(), '.env.local');
const exampleEnvFilePath = resolve(process.cwd(), '.env.local.example');
const outputPath = resolve(process.cwd(), '.dev.vars');
const overrideEntries = process.argv.slice(2);

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
	try {
		envMap = parseEnvFile(readFileSync(exampleEnvFilePath, 'utf8'));
		console.warn(`Using ${exampleEnvFilePath} as the source for .dev.vars because ${envFilePath} was not found.`);
	} catch {
		console.warn(`No ${envFilePath} or ${exampleEnvFilePath} found. Writing .dev.vars from overrides only.`);
	}
}

for (const entry of overrideEntries) {
	const separatorIndex = entry.indexOf('=');
	if (separatorIndex === -1) {
		continue;
	}

	const key = entry.slice(0, separatorIndex).trim();
	const value = entry.slice(separatorIndex + 1);
	if (!key) {
		continue;
	}

	envMap[key] = value;
}

const docsEntries = Object.entries(envMap)
	.filter(([key]) => key.startsWith('TREESEED_'))
	.map(([key, value]) => `${key}=${value}`);

mkdirSync(resolve(process.cwd(), '.local'), { recursive: true });
writeFileSync(outputPath, `${docsEntries.join('\n')}\n`, 'utf8');
console.log(`Wrote ${outputPath}`);
