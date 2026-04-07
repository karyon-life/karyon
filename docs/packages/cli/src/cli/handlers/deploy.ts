import type { TreeseedCommandHandler } from '../types.js';
import { applyTreeseedEnvironmentToProcess } from '../../../scripts/config-runtime-lib.ts';
import {
	assertDeploymentInitialized,
	createBranchPreviewDeployTarget,
	createPersistentDeployTarget,
	deployTargetLabel,
	ensureGeneratedWranglerConfig,
	finalizeDeploymentState,
	runRemoteD1Migrations,
} from '../../../scripts/deploy-lib.ts';
import { currentManagedBranch, PRODUCTION_BRANCH, STAGING_BRANCH } from '../../../scripts/git-workflow-lib.ts';
import { packageScriptPath, wranglerBin } from '../../../scripts/package-tools.ts';
import { runTenantDeployPreflight } from '../../../scripts/save-deploy-preflight-lib.ts';

function inferEnvironmentFromBranch(tenantRoot: string) {
	const branch = currentManagedBranch(tenantRoot);
	if (branch === STAGING_BRANCH) return 'staging';
	if (branch === PRODUCTION_BRANCH) return 'prod';
	return null;
}

export const handleDeploy: TreeseedCommandHandler = (invocation, context) => {
	const tenantRoot = context.cwd;
	const environment = typeof invocation.args.environment === 'string' ? invocation.args.environment : undefined;
	const targetBranch = typeof invocation.args.targetBranch === 'string' ? invocation.args.targetBranch : undefined;
	const dryRun = invocation.args.dryRun === true;
	const only = typeof invocation.args.only === 'string' ? invocation.args.only : null;
	const name = typeof invocation.args.name === 'string' ? invocation.args.name : null;

	const target = targetBranch
		? createBranchPreviewDeployTarget(targetBranch)
		: createPersistentDeployTarget(environment ?? (context.env.CI ? inferEnvironmentFromBranch(tenantRoot) : null));
	const scope = targetBranch ? 'staging' : String(environment ?? (context.env.CI ? inferEnvironmentFromBranch(tenantRoot) : ''));

	applyTreeseedEnvironmentToProcess({ tenantRoot, scope });

	const allowedSteps = new Set(['migrate', 'build', 'publish']);
	if (only && !allowedSteps.has(only)) {
		throw new Error(`Unsupported deploy step "${only}". Expected one of ${[...allowedSteps].join(', ')}.`);
	}

	const shouldRun = (step: string) => !only || only === step;
	if (name) {
		context.write(`Deploy target label: ${name}`, 'stdout');
	}

	if (scope === 'local') {
		runTenantDeployPreflight({ cwd: tenantRoot, scope: 'local' });
		const buildOnly = context.spawn(process.execPath, [packageScriptPath('tenant-build')], {
			cwd: tenantRoot,
			env: { ...context.env },
			stdio: 'inherit',
		});
		return {
			exitCode: buildOnly.status ?? 1,
			stdout: buildOnly.status === 0 ? ['Treeseed local deploy completed as a build-only publish target.'] : [],
		};
	}

	assertDeploymentInitialized(tenantRoot, { target });
	runTenantDeployPreflight({ cwd: tenantRoot, scope });
	const { wranglerPath } = ensureGeneratedWranglerConfig(tenantRoot, { target });

	if (shouldRun('migrate')) {
		const result = runRemoteD1Migrations(tenantRoot, { dryRun, target });
		context.write(`${dryRun ? 'Planned' : 'Applied'} remote migrations for ${result.databaseName}.`, 'stdout');
	}

	if (shouldRun('build')) {
		if (dryRun) {
			context.write('Dry run: skipped tenant build.', 'stdout');
		} else {
			const buildResult = context.spawn(process.execPath, [packageScriptPath('tenant-build')], {
				cwd: tenantRoot,
				env: { ...context.env },
				stdio: 'inherit',
			});
			if ((buildResult.status ?? 1) !== 0) {
				return { exitCode: buildResult.status ?? 1 };
			}
		}
	}

	if (shouldRun('publish')) {
		if (dryRun) {
			context.write(`Dry run: would deploy ${deployTargetLabel(target)} with generated Wrangler config at ${wranglerPath}.`, 'stdout');
		} else {
			const publishResult = context.spawn(process.execPath, [wranglerBin, 'deploy', '--config', wranglerPath], {
				cwd: tenantRoot,
				env: { ...context.env },
				stdio: 'inherit',
			});
			if ((publishResult.status ?? 1) !== 0) {
				return { exitCode: publishResult.status ?? 1 };
			}
			finalizeDeploymentState(tenantRoot, { target });
		}
	}

	return { exitCode: 0 };
};
