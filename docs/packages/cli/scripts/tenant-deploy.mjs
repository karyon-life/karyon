#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import {
	collectMissingDeployInputs,
	ensureGeneratedWranglerConfig,
	finalizeDeploymentState,
	printDeploySummary,
	provisionCloudflareResources,
	promptForMissingDeployInputs,
	runRemoteD1Migrations,
	syncCloudflareSecrets,
	validateDeployPrerequisites,
} from './deploy-lib.mjs';
import { ensureDeployWorkflow, ensureGitHubSecrets } from './github-automation-lib.mjs';
import { packageScriptPath, wranglerBin } from './package-tools.mjs';
import { runTenantDeployPreflight } from './save-deploy-preflight-lib.mjs';

const tenantRoot = process.cwd();
const args = process.argv.slice(2);

function writeDeployReport(payload) {
	const target = process.env.TREESEED_DEPLOY_REPORT_PATH;
	if (!target) {
		return;
	}

	const filePath = resolve(target);
	mkdirSync(dirname(filePath), { recursive: true });
	writeFileSync(filePath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
}

function parseArgs(argv) {
	const parsed = {
		dryRun: false,
		only: null,
		name: null,
	};

	const rest = [...argv];
	while (rest.length) {
		const current = rest.shift();
		if (!current) continue;
		if (current === '--dry-run') {
			parsed.dryRun = true;
			continue;
		}
		if (current === '--only') {
			parsed.only = rest.shift() ?? null;
			continue;
		}
		if (current === '--name') {
			parsed.name = rest.shift() ?? null;
			continue;
		}
		throw new Error(`Unknown deploy argument: ${current}`);
	}

	return parsed;
}

function runNodeScript(scriptPath, scriptArgs = [], env = {}) {
	const result = spawnSync(process.execPath, [scriptPath, ...scriptArgs], {
		stdio: 'inherit',
		cwd: tenantRoot,
		env: { ...process.env, ...env },
	});

	if (result.status !== 0) {
		process.exit(result.status ?? 1);
	}
}

function runWranglerDeploy(configPath) {
	const result = spawnSync(process.execPath, [wranglerBin, 'deploy', '--config', configPath], {
		stdio: 'inherit',
		cwd: tenantRoot,
		env: { ...process.env },
	});

	if (result.status !== 0) {
		process.exit(result.status ?? 1);
	}
}

async function main() {
	const options = parseArgs(args);
	const allowedSteps = new Set(['provision', 'secrets', 'migrate', 'build', 'publish']);

	if (options.only && !allowedSteps.has(options.only)) {
		throw new Error(`Unsupported deploy step "${options.only}". Expected one of ${[...allowedSteps].join(', ')}.`);
	}

	const shouldRun = (step) => !options.only || options.only === step;
	const shouldRunPreflight = !options.only;
	const needsRemoteAccess =
		!options.dryRun &&
		(['provision', 'secrets', 'migrate', 'publish'].some((step) => shouldRun(step)));

	if (options.name) {
		console.log(`Deploy target label: ${options.name}`);
	}

	if (shouldRunPreflight) {
		try {
			runTenantDeployPreflight({ cwd: tenantRoot });
		} catch (error) {
			const kind = error?.kind ?? 'preflight_failed';
			writeDeployReport({
				ok: false,
				kind,
				message: error instanceof Error ? error.message : String(error),
			});
			throw error;
		}
	}

	if (needsRemoteAccess) {
		const { prompted, provided } = await promptForMissingDeployInputs(tenantRoot);
		if (prompted && provided.length > 0) {
			console.log(`Captured ${provided.length} missing deploy value(s) for this run.`);
		}
	}

	if (needsRemoteAccess) {
		try {
			validateDeployPrerequisites(tenantRoot, { requireRemote: true });
		} catch (error) {
			const missing = collectMissingDeployInputs(tenantRoot);
			if (missing.length > 0 && (!process.stdin.isTTY || !process.stdout.isTTY)) {
				console.error('Treeseed deploy is missing required values and cannot prompt in this environment.');
				console.error('Provide them through environment variables or CI secrets before retrying:');
				for (const item of missing) {
					console.error(`- ${item.key}`);
				}
			}
			writeDeployReport({
				ok: false,
				kind: 'auth_failed',
				message: error instanceof Error ? error.message : String(error),
				missingInputs: missing.map((item) => item.key),
			});
			throw error;
		}
	}

	const workflowStatus = ensureDeployWorkflow(tenantRoot);
	if (workflowStatus.changed) {
		console.log(`Updated deploy workflow at ${workflowStatus.workflowPath}.`);
	}

	const secretStatus = ensureGitHubSecrets(tenantRoot, { dryRun: options.dryRun });
	if (secretStatus.created.length > 0) {
		console.log(`${options.dryRun ? 'Would create' : 'Created'} ${secretStatus.created.length} GitHub secret(s).`);
	}

	const { wranglerPath } = ensureGeneratedWranglerConfig(tenantRoot);

	if (shouldRun('provision')) {
		const summary = provisionCloudflareResources(tenantRoot, { dryRun: options.dryRun });
		printDeploySummary(summary);
		ensureGeneratedWranglerConfig(tenantRoot);
	}

	if (shouldRun('secrets')) {
		const syncedSecrets = syncCloudflareSecrets(tenantRoot, { dryRun: options.dryRun });
		console.log(`Secret sync ${options.dryRun ? 'planned' : 'completed'} for ${syncedSecrets.length} secret(s).`);
	}

	if (shouldRun('migrate')) {
		const result = runRemoteD1Migrations(tenantRoot, { dryRun: options.dryRun });
		console.log(`${options.dryRun ? 'Planned' : 'Applied'} remote migrations for ${result.databaseName}.`);
	}

	if (shouldRun('build') && options.only) {
		if (options.dryRun) {
			console.log('Dry run: skipped tenant build.');
		} else {
			runNodeScript(packageScriptPath('tenant-build'));
		}
	}

	if (shouldRun('publish')) {
		if (options.dryRun) {
			console.log(`Dry run: would deploy with generated Wrangler config at ${resolve(wranglerPath)}.`);
		} else {
			runWranglerDeploy(wranglerPath);
			finalizeDeploymentState(tenantRoot);
		}
	}

	writeDeployReport({
		ok: true,
		kind: 'success',
		dryRun: options.dryRun,
		only: options.only,
	});
}

try {
	await main();
} catch (error) {
	console.error(error instanceof Error ? error.message : String(error));
	process.exit(1);
}
