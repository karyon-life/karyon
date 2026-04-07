import type { TreeseedCommandHandler } from '../types.js';
import { applyTreeseedEnvironmentToProcess } from '../../../scripts/config-runtime-lib.ts';
import {
	cleanupDestroyedState,
	createBranchPreviewDeployTarget,
	destroyCloudflareResources,
	loadDeployState,
	printDestroySummary,
	validateDestroyPrerequisites,
} from '../../../scripts/deploy-lib.ts';
import {
	assertFeatureBranch,
	deleteLocalBranch,
	deleteRemoteBranch,
	mergeCurrentBranchIntoStaging,
} from '../../../scripts/git-workflow-lib.ts';
import { loadTreeseedDeployConfig } from '@treeseed/core/deploy/config';
import { runWorkspaceSavePreflight } from '../../../scripts/save-deploy-preflight-lib.ts';

export const handleClose: TreeseedCommandHandler = (_invocation, context) => {
	const tenantRoot = context.cwd;
	const featureBranch = assertFeatureBranch(tenantRoot);
	const previewTarget = createBranchPreviewDeployTarget(featureBranch);
	const deployConfig = loadTreeseedDeployConfig();
	const previewState = loadDeployState(tenantRoot, deployConfig, { target: previewTarget });

	runWorkspaceSavePreflight({ cwd: tenantRoot });
	const repoDir = mergeCurrentBranchIntoStaging(tenantRoot, featureBranch);

	if (previewState.readiness?.initialized) {
		applyTreeseedEnvironmentToProcess({ tenantRoot, scope: 'staging' });
		validateDestroyPrerequisites(tenantRoot, { requireRemote: true });
		const result = destroyCloudflareResources(tenantRoot, { target: previewTarget });
		printDestroySummary(result);
	}

	cleanupDestroyedState(tenantRoot, { target: previewTarget });
	deleteRemoteBranch(repoDir, featureBranch);
	deleteLocalBranch(repoDir, featureBranch);

	return {
		exitCode: 0,
		stdout: [
			'Treeseed close completed successfully.',
			`Merged ${featureBranch} into staging and removed branch artifacts.`,
		],
	};
};
