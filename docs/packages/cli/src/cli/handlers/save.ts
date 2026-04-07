import type { TreeseedCommandHandler } from '../types.js';
import { applyTreeseedEnvironmentToProcess } from '../../../scripts/config-runtime-lib.ts';
import {
	collectMergeConflictReport,
	currentBranch,
	formatMergeConflictReport,
	hasMeaningfulChanges,
	originRemoteUrl,
	repoRoot,
} from '../../../scripts/workspace-save-lib.ts';
import { PRODUCTION_BRANCH, STAGING_BRANCH, remoteBranchExists } from '../../../scripts/git-workflow-lib.ts';
import { run, workspaceRoot } from '../../../scripts/workspace-tools.ts';
import { runWorkspaceSavePreflight } from '../../../scripts/save-deploy-preflight-lib.ts';

export const handleSave: TreeseedCommandHandler = (invocation, context) => {
	const optionsHotfix = invocation.args.hotfix === true;
	const message = invocation.positionals.join(' ').trim();
	const root = workspaceRoot();
	const gitRoot = repoRoot(root);
	const branch = currentBranch(gitRoot);
	const scope = branch === STAGING_BRANCH ? 'staging' : branch === PRODUCTION_BRANCH ? 'prod' : 'local';
	applyTreeseedEnvironmentToProcess({ tenantRoot: root, scope });

	if (!message) {
		return { exitCode: 1, stderr: ['Treeseed save requires a commit message. Usage: treeseed save <message>'] };
	}
	if (!branch) {
		return { exitCode: 1, stderr: ['Treeseed save requires an active git branch.'] };
	}
	if (branch === PRODUCTION_BRANCH && !optionsHotfix) {
		return {
			exitCode: 1,
			stderr: ['Treeseed save is blocked on main. Use `treeseed release` for normal production promotion or `treeseed save --hotfix` for an explicit hotfix.'],
		};
	}

	try {
		originRemoteUrl(gitRoot);
	} catch {
		return { exitCode: 1, stderr: ['Treeseed save requires an origin remote.'] };
	}

	try {
		runWorkspaceSavePreflight({ cwd: root });
	} catch (error) {
		return { exitCode: (error as any)?.exitCode ?? 1, stderr: [error instanceof Error ? error.message : String(error)] };
	}

	if (!hasMeaningfulChanges(gitRoot)) {
		return { exitCode: 1, stderr: ['Treeseed save found no meaningful repository changes to commit.'] };
	}

	run('git', ['add', '-A'], { cwd: gitRoot });
	run('git', ['commit', '-m', message], { cwd: gitRoot });

	try {
		if (remoteBranchExists(gitRoot, branch)) {
			run('git', ['pull', '--rebase', 'origin', branch], { cwd: gitRoot });
			run('git', ['push', 'origin', branch], { cwd: gitRoot });
		} else {
			run('git', ['push', '-u', 'origin', branch], { cwd: gitRoot });
		}
	} catch {
		const report = collectMergeConflictReport(gitRoot);
		return {
			exitCode: 12,
			stderr: [formatMergeConflictReport(report, gitRoot, branch)],
		};
	}

	return {
		exitCode: 0,
		stdout: ['Treeseed save completed successfully.', `Branch: ${branch}`, `Environment scope: ${scope}`],
	};
};
