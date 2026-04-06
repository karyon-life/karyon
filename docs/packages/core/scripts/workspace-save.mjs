#!/usr/bin/env node

import { ensureGitHubDeployAutomation, ensureDeployWorkflow } from './github-automation-lib.mjs';
import {
	MERGE_CONFLICT_EXIT_CODE,
	applyWorkspaceVersionChanges,
	collectMergeConflictReport,
	currentBranch,
	formatMergeConflictReport,
	hasMeaningfulChanges,
	originRemoteUrl,
	planWorkspaceVersionChanges,
	repoRoot,
} from './workspace-save-lib.mjs';
import { run, workspaceRoot } from './workspace-tools.mjs';
import { packageScriptPath } from './package-tools.mjs';

const message = process.argv.slice(2).join(' ').trim();
const root = workspaceRoot();
const gitRoot = repoRoot(root);

if (!message) {
	console.error('Treeseed save requires a commit message. Usage: treeseed save <message>');
	process.exit(1);
}

if (currentBranch(gitRoot) !== 'main') {
	console.error(`Treeseed save must run from the main branch. Current branch: ${currentBranch(gitRoot)}`);
	process.exit(1);
}

try {
	originRemoteUrl(gitRoot);
} catch {
	console.error('Treeseed save requires an origin remote.');
	process.exit(1);
}

ensureDeployWorkflow(root);

const versionPlan = applyWorkspaceVersionChanges(planWorkspaceVersionChanges(root));

if (!hasMeaningfulChanges(gitRoot)) {
	console.error('Treeseed save found no meaningful repository changes to commit.');
	process.exit(1);
}

run('npm', ['install'], { cwd: root });
run('git', ['add', '-A'], { cwd: gitRoot });
run('git', ['commit', '-m', message], { cwd: gitRoot });

try {
	run('git', ['pull', '--rebase', 'origin', 'main'], { cwd: gitRoot });
} catch (error) {
	const report = collectMergeConflictReport(gitRoot);
	console.error(formatMergeConflictReport(report, gitRoot));
	process.exit(MERGE_CONFLICT_EXIT_CODE);
}

run(process.execPath, [packageScriptPath('workspace-release-verify'), '--changed'], { cwd: root });
const automation = ensureGitHubDeployAutomation(root, { dryRun: false });
run('git', ['push', 'origin', 'main'], { cwd: gitRoot });

console.log('Treeseed save completed successfully.');
console.log(`Workflow synced: ${automation.workflow.changed ? 'yes' : 'no'}`);
console.log(`GitHub secrets created: ${automation.secrets.created.length}`);
console.log(`Versioned packages: ${[...versionPlan.bumped].join(', ') || 'none'}`);
