#!/usr/bin/env node

import { spawn } from 'node:child_process';

const child = spawn(
	process.execPath,
	[
		'--experimental-strip-types',
		'--experimental-transform-types',
		'./src/utils/agents/cli.ts',
		...process.argv.slice(2),
	],
	{
		cwd: process.cwd(),
		stdio: 'inherit',
		env: process.env,
	},
);

child.on('exit', (code) => {
	process.exit(code ?? 1);
});
