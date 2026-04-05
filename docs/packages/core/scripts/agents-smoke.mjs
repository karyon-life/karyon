#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const repoRoot = fileURLToPath(new URL('..', import.meta.url));

const child = spawn(
	process.execPath,
	[
		'--experimental-strip-types',
		'--experimental-transform-types',
		'./src/utils/agents/testing/agents-smoke.ts',
		...process.argv.slice(2),
	],
	{
		cwd: repoRoot,
		stdio: 'inherit',
		env: process.env,
	},
);

child.on('exit', (code) => {
	process.exit(code ?? 0);
});
