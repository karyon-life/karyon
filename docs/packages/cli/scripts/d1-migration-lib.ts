import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { wranglerBin } from './package-tools.ts';

const DATABASE_BINDING = 'SITE_DATA_DB';

function runWrangler(args, { cwd, capture = false } = {}) {
	return spawnSync(process.execPath, [wranglerBin, ...args], {
		cwd,
		env: { ...process.env },
		stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
		encoding: capture ? 'utf8' : undefined,
	});
}

function executeSqlFile({ cwd, wranglerConfig, filePath, persistTo }) {
	const args = ['d1', 'execute', DATABASE_BINDING, '--local', '--config', wranglerConfig, '--file', filePath];
	if (persistTo) {
		args.push('--persist-to', persistTo);
	}

	const result = runWrangler(args, { cwd });
	if (result.status !== 0) {
		process.exit(result.status ?? 1);
	}
}

function executeSqlCommand({ cwd, wranglerConfig, command, persistTo }) {
	const args = ['d1', 'execute', DATABASE_BINDING, '--local', '--config', wranglerConfig, '--command', command];
	if (persistTo) {
		args.push('--persist-to', persistTo);
	}

	const result = runWrangler(args, { cwd });
	if (result.status !== 0) {
		process.exit(result.status ?? 1);
	}
}

function queryExistingColumns({ cwd, wranglerConfig, persistTo }) {
	const args = ['d1', 'execute', DATABASE_BINDING, '--local', '--config', wranglerConfig, '--json', '--command', "PRAGMA table_info('agent_runs');"];
	if (persistTo) {
		args.push('--persist-to', persistTo);
	}

	const result = runWrangler(args, { cwd, capture: true });
	if (result.status !== 0) {
		if (result.stdout) process.stdout.write(result.stdout);
		if (result.stderr) process.stderr.write(result.stderr);
		process.exit(result.status ?? 1);
	}

	const parsed = JSON.parse(result.stdout);
	const rows = (Array.isArray(parsed) ? parsed : [parsed]).flatMap((entry) => entry.results ?? []);
	return new Set(rows.map((row) => row.name).filter(Boolean));
}

export function runLocalD1Migrations({ cwd, wranglerConfig, migrationsRoot, persistTo }) {
	for (const migration of ['0001_subscribers.sql', '0002_agent_runtime.sql']) {
		const filePath = resolve(migrationsRoot, migration);
		if (!existsSync(filePath)) {
			console.error(`Unable to find migration file at ${filePath}.`);
			process.exit(1);
		}

		executeSqlFile({ cwd, wranglerConfig, filePath, persistTo });
	}

	const existingColumns = queryExistingColumns({ cwd, wranglerConfig, persistTo });
	const additiveColumns = [
		['handler_kind', 'TEXT'],
		['trigger_kind', 'TEXT'],
		['claimed_message_id', 'INTEGER'],
		['commit_sha', 'TEXT'],
		['changed_paths', 'TEXT'],
		['error_category', 'TEXT'],
	];

	for (const [columnName, columnType] of additiveColumns) {
		if (existingColumns.has(columnName)) {
			continue;
		}

		executeSqlCommand({
			cwd,
			wranglerConfig,
			persistTo,
			command: `ALTER TABLE agent_runs ADD COLUMN ${columnName} ${columnType};`,
		});
	}
}
