import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import type { TreeseedCommandHandler } from '../types.js';
import { applyTreeseedEnvironmentToProcess } from '../../../scripts/config-runtime-lib.ts';
import { PRODUCTION_BRANCH, STAGING_BRANCH, mergeStagingIntoMain, prepareReleaseBranches, pushBranch } from '../../../scripts/git-workflow-lib.ts';
import { applyWorkspaceVersionChanges, incrementVersion, planWorkspaceReleaseBump, repoRoot } from '../../../scripts/workspace-save-lib.ts';
import { run, workspaceRoot } from '../../../scripts/workspace-tools.ts';
import { runWorkspaceSavePreflight } from '../../../scripts/save-deploy-preflight-lib.ts';

function bumpRootPackageJson(root: string, level: string) {
	const packageJsonPath = resolve(root, 'package.json');
	const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'));
	packageJson.version = incrementVersion(packageJson.version, level);
	writeFileSync(packageJsonPath, `${JSON.stringify(packageJson, null, 2)}\n`, 'utf8');
	return packageJson.version;
}

export const handleRelease: TreeseedCommandHandler = (invocation, context) => {
	const level = ['major', 'minor', 'patch'].find((candidate) => invocation.args[candidate] === true);
	const root = workspaceRoot();
	const gitRoot = repoRoot(root);

	prepareReleaseBranches(root);
	applyTreeseedEnvironmentToProcess({ tenantRoot: root, scope: 'staging' });
	runWorkspaceSavePreflight({ cwd: root });

	const plan = planWorkspaceReleaseBump(level, root);
	applyWorkspaceVersionChanges(plan);
	const rootVersion = bumpRootPackageJson(root, level);

	run('git', ['checkout', STAGING_BRANCH], { cwd: gitRoot });
	run('git', ['add', '-A'], { cwd: gitRoot });
	run('git', ['commit', '-m', `release: ${level} bump`], { cwd: gitRoot });
	pushBranch(gitRoot, STAGING_BRANCH);
	mergeStagingIntoMain(root);

	return {
		exitCode: 0,
		stdout: [
			'Treeseed release completed successfully.',
			`Staging branch: ${STAGING_BRANCH}`,
			`Production branch: ${PRODUCTION_BRANCH}`,
			`Release level: ${level}`,
			`Root version: ${rootVersion}`,
		],
	};
};
