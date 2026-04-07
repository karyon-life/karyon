import type { TreeseedCommandHandler } from '../types.js';
import {
	applyTreeseedEnvironmentToProcess,
	assertTreeseedCommandEnvironment,
} from '../../../scripts/config-runtime-lib.ts';
import {
	createBranchPreviewDeployTarget,
	deployTargetLabel,
	ensureGeneratedWranglerConfig,
	finalizeDeploymentState,
	printDeploySummary,
	provisionCloudflareResources,
	runRemoteD1Migrations,
	syncCloudflareSecrets,
	validateDeployPrerequisites,
} from '../../../scripts/deploy-lib.ts';
import { createFeatureBranchFromStaging, pushBranch } from '../../../scripts/git-workflow-lib.ts';
import { packageScriptPath, wranglerBin } from '../../../scripts/package-tools.ts';

export const handleStart: TreeseedCommandHandler = (invocation, context) => {
	const branchName = invocation.positionals[0];
	const preview = invocation.args.preview === true;
	const tenantRoot = context.cwd;
	const result = createFeatureBranchFromStaging(tenantRoot, branchName);
	pushBranch(result.repoDir, branchName, { setUpstream: true });

	if (!preview) {
		return {
			exitCode: 0,
			stdout: [
				`Created feature branch ${branchName} from staging.`,
				'Preview mode is disabled. Use local development for this branch.',
			],
		};
	}

	applyTreeseedEnvironmentToProcess({ tenantRoot, scope: 'staging' });
	assertTreeseedCommandEnvironment({ tenantRoot, scope: 'staging', purpose: 'deploy' });
	validateDeployPrerequisites(tenantRoot, { requireRemote: true });

	const target = createBranchPreviewDeployTarget(branchName);
	const summary = provisionCloudflareResources(tenantRoot, { target });
	printDeploySummary(summary);
	const { wranglerPath } = ensureGeneratedWranglerConfig(tenantRoot, { target });
	syncCloudflareSecrets(tenantRoot, { target });
	runRemoteD1Migrations(tenantRoot, { target });

	const buildResult = context.spawn(process.execPath, [packageScriptPath('tenant-build')], {
		cwd: tenantRoot,
		env: { ...context.env },
		stdio: 'inherit',
	});
	if ((buildResult.status ?? 1) !== 0) {
		return { exitCode: buildResult.status ?? 1 };
	}

	const deployResult = context.spawn(process.execPath, [wranglerBin, 'deploy', '--config', wranglerPath], {
		cwd: tenantRoot,
		env: { ...context.env },
		stdio: 'inherit',
	});
	if ((deployResult.status ?? 1) !== 0) {
		return { exitCode: deployResult.status ?? 1 };
	}

	const state = finalizeDeploymentState(tenantRoot, { target });
	return {
		exitCode: 0,
		stdout: [
			`Treeseed start preview completed for ${branchName}.`,
			`Target: ${deployTargetLabel(target)}`,
			`Preview URL: ${state.lastDeployedUrl}`,
		],
	};
};
