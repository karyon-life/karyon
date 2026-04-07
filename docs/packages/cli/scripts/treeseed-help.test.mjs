import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { findCommandSpec, listCommandNames, runTreeseedCli } from '../dist/cli/main.js';

function makeWorkspaceRoot() {
	const root = mkdtempSync(join(tmpdir(), 'treeseed-help-workspace-'));
	writeFileSync(resolve(root, 'package.json'), JSON.stringify({
		name: 'help-test',
		private: true,
		workspaces: ['packages/*'],
	}, null, 2));
	return root;
}

async function runCli(args, options = {}) {
	const writes = [];
	const spawns = [];
	const exitCode = await runTreeseedCli(args, {
		cwd: options.cwd ?? process.cwd(),
		env: { ...process.env, ...(options.env ?? {}) },
		write(output, stream) {
			writes.push({ output, stream });
		},
		spawn(command, spawnArgs) {
			spawns.push({ command, args: spawnArgs });
			return { status: options.spawnStatus ?? 0 };
		},
	});

	return {
		exitCode,
		writes,
		spawns,
		stdout: writes.filter((entry) => entry.stream === 'stdout').map((entry) => entry.output).join('\n'),
		stderr: writes.filter((entry) => entry.stream === 'stderr').map((entry) => entry.output).join('\n'),
		output: writes.map((entry) => entry.output).join('\n'),
	};
}

test('treeseed with no args prints top-level help and exits successfully', async () => {
	const result = await runCli([]);
	assert.equal(result.exitCode, 0);
	assert.match(result.output, /Treeseed CLI/);
	assert.match(result.output, /Primary Workflow/);
});

test('treeseed help entrypoints produce top-level help', async () => {
	const defaultHelp = await runCli(['--help']);
	const shortHelp = await runCli(['-h']);
	const helpCommand = await runCli(['help']);
	assert.equal(defaultHelp.exitCode, 0);
	assert.equal(shortHelp.exitCode, 0);
	assert.equal(helpCommand.exitCode, 0);
	assert.equal(defaultHelp.output, shortHelp.output);
	assert.equal(defaultHelp.output, helpCommand.output);
});

test('treeseed command help renders without executing the command', async () => {
	const helpViaCommand = await runCli(['help', 'deploy']);
	const helpViaFlag = await runCli(['deploy', '--help']);
	assert.equal(helpViaCommand.exitCode, 0);
	assert.equal(helpViaFlag.exitCode, 0);
	assert.match(helpViaCommand.output, /deploy  Run phase-2 deploy/);
	assert.match(helpViaCommand.output, /--environment <scope>/);
	assert.equal(helpViaCommand.output, helpViaFlag.output);
	assert.equal(helpViaFlag.spawns.length, 0);
});

test('major workflow commands have usage, options, and examples in help', async () => {
	for (const command of ['start', 'save', 'release', 'destroy', 'config']) {
		const result = await runCli(['help', command]);
		assert.equal(result.exitCode, 0, `help for ${command} should exit successfully`);
		assert.match(result.output, /Usage/);
		assert.match(result.output, /Examples/);
	}
});

test('unknown command suggests nearest valid commands', async () => {
	const result = await runCli(['relase']);
	assert.equal(result.exitCode, 1);
	assert.match(result.stderr, /Unknown treeseed command: relase/);
	assert.match(result.stderr, /release/);
	assert.match(result.stderr, /treeseed help/);
});

test('workspace-only adapter commands still route correctly when not requesting help', async () => {
	const workspaceRoot = makeWorkspaceRoot();
	const result = await runCli(['test:e2e'], { cwd: workspaceRoot });
	assert.equal(result.exitCode, 0);
	assert.equal(result.spawns.length, 1);
	assert.match(result.spawns[0].args[0], /workspace-command-e2e/);
});

test('command metadata stays aligned with help coverage', () => {
	for (const name of listCommandNames()) {
		const command = findCommandSpec(name);
		assert.ok(command?.summary, `${name} should have summary`);
		assert.ok(command?.description, `${name} should have description`);
		assert.ok(command?.executionMode, `${name} should declare an execution mode`);
	}
});
