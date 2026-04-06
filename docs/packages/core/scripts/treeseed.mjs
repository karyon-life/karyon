#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { isWorkspaceRoot, packageRoot, packageScriptPath } from './package-tools.mjs';

const [command, ...args] = process.argv.slice(2);

const COMMAND_MAP = new Map([
	['dev', packageScriptPath('tenant-dev')],
	['dev:watch', packageScriptPath('tenant-dev')],
	['build', packageScriptPath('tenant-build')],
	['check', packageScriptPath('tenant-check')],
	['deploy', packageScriptPath('tenant-deploy')],
	['destroy', packageScriptPath('tenant-destroy')],
	['preview', packageScriptPath('tenant-astro-command')],
	['astro', packageScriptPath('tenant-astro-command')],
	['sync:devvars', packageScriptPath('sync-dev-vars')],
	['mailpit:up', packageScriptPath('ensure-mailpit')],
	['mailpit:down', packageScriptPath('stop-mailpit')],
	['mailpit:logs', packageScriptPath('logs-mailpit')],
	['d1:migrate:local', packageScriptPath('tenant-d1-migrate-local')],
	['cleanup:markdown', packageScriptPath('cleanup-markdown')],
	['cleanup:markdown:check', packageScriptPath('cleanup-markdown')],
	['starlight:patch', packageScriptPath('patch-starlight-content-path')],
	['agents', packageScriptPath('treeseed-agents')],
	['init', packageScriptPath('scaffold-site')],
]);

const WORKSPACE_COMMANDS = new Map([
	['test:unit', { script: packageScriptPath('workspace-test-unit'), extraArgs: [] }],
	['test:release', { script: packageScriptPath('workspace-release-verify'), extraArgs: [] }],
	['test:release:full', { script: packageScriptPath('workspace-release-verify'), extraArgs: ['--full-smoke'] }],
	['release:verify', { script: packageScriptPath('workspace-release-verify'), extraArgs: ['--full-smoke'] }],
	['release:publish:changed', { script: packageScriptPath('workspace-publish-changed-packages'), extraArgs: [] }],
	['save', { script: packageScriptPath('workspace-save'), extraArgs: [] }],
]);

const PACKAGE_SCRIPT_COMMANDS = new Set(['test', 'test:unit', 'test:integration', 'test:e2e', 'test:smoke']);

if (!command) {
	console.error('Usage: treeseed <command> [...args]');
	process.exit(1);
}

const workspaceCommand = WORKSPACE_COMMANDS.get(command);
if (workspaceCommand && isWorkspaceRoot(process.cwd())) {
	const result = spawnSync(process.execPath, [workspaceCommand.script, ...workspaceCommand.extraArgs, ...args], {
		stdio: 'inherit',
		cwd: process.cwd(),
		env: { ...process.env },
	});
	process.exit(result.status ?? 1);
}

if (PACKAGE_SCRIPT_COMMANDS.has(command)) {
	const result = spawnSync('npm', ['run', command, '--', ...args], {
		stdio: 'inherit',
		cwd: packageRoot,
		env: { ...process.env },
	});
	process.exit(result.status ?? 1);
}

const scriptPath = COMMAND_MAP.get(command);
if (!scriptPath) {
	console.error(`Unknown treeseed command: ${command}`);
	process.exit(1);
}

const commandArgs =
	command === 'preview' || command === 'astro'
		? args
		: command === 'dev:watch'
			? ['--watch', ...args]
		: command === 'cleanup:markdown:check'
			? ['--check', ...args]
			: command === 'cleanup:markdown'
				? ['--write', ...args]
				: args;

const result = spawnSync(process.execPath, [scriptPath, ...commandArgs], {
	stdio: 'inherit',
	cwd: process.cwd(),
	env: { ...process.env },
});

process.exit(result.status ?? 1);
