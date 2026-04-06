#!/usr/bin/env node

import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { mkdirSync } from 'node:fs';
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
import { runWorkspaceSavePreflight, validateSaveAutomationPrerequisites } from './save-deploy-preflight-lib.mjs';

function writeSaveReport(payload) {
	const target = process.env.TREESEED_SAVE_REPORT_PATH;
	if (!target) {
		return;
	}

	const filePath = resolve(target);
	mkdirSync(dirname(filePath), { recursive: true });
	writeFileSync(filePath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
}

const message = process.argv.slice(2).join(' ').trim();
const root = workspaceRoot();
const gitRoot = repoRoot(root);

if (!message) {
	writeSaveReport({ ok: false, kind: 'usage', message: 'Treeseed save requires a commit message.' });
	console.error('Treeseed save requires a commit message. Usage: treeseed save <message>');
	process.exit(1);
}

if (currentBranch(gitRoot) !== 'main') {
	writeSaveReport({
		ok: false,
		kind: 'wrong_branch',
		branch: currentBranch(gitRoot),
		message: `Treeseed save must run from the main branch. Current branch: ${currentBranch(gitRoot)}`,
	});
	console.error(`Treeseed save must run from the main branch. Current branch: ${currentBranch(gitRoot)}`);
	process.exit(1);
}

try {
	originRemoteUrl(gitRoot);
} catch {
	writeSaveReport({ ok: false, kind: 'missing_origin', message: 'Treeseed save requires an origin remote.' });
	console.error('Treeseed save requires an origin remote.');
	process.exit(1);
}

try {
	validateSaveAutomationPrerequisites({ cwd: root });
} catch (error) {
	const kind = error?.kind ?? 'auth_failed';
	const payload = {
		ok: false,
		kind,
		message: error instanceof Error ? error.message : String(error),
		...(error?.missingEnv ? { missingEnv: error.missingEnv } : {}),
		...(error?.details ? { details: error.details } : {}),
	};
	writeSaveReport(payload);
	console.error(payload.message);
	process.exit(1);
}

try {
	runWorkspaceSavePreflight({ cwd: root });
} catch (error) {
	const kind = error?.kind ?? 'preflight_failed';
	const payload = {
		ok: false,
		kind,
		message: error instanceof Error ? error.message : String(error),
	};
	writeSaveReport(payload);
	console.error(payload.message);
	process.exit(error?.exitCode ?? 1);
}

ensureDeployWorkflow(root);

const versionPlan = planWorkspaceVersionChanges(root);
const shouldInstall = versionPlan.touched.size > 0;
applyWorkspaceVersionChanges(versionPlan);

if (!hasMeaningfulChanges(gitRoot)) {
	writeSaveReport({ ok: false, kind: 'no_changes', message: 'Treeseed save found no meaningful repository changes to commit.' });
	console.error('Treeseed save found no meaningful repository changes to commit.');
	process.exit(1);
}

if (shouldInstall) {
	run('npm', ['install'], { cwd: root });
}
run('git', ['add', '-A'], { cwd: gitRoot });
run('git', ['commit', '-m', message], { cwd: gitRoot });

try {
	run('git', ['pull', '--rebase', 'origin', 'main'], { cwd: gitRoot });
} catch (error) {
	const report = collectMergeConflictReport(gitRoot);
	writeSaveReport({
		ok: false,
		kind: 'merge_conflict',
		exitCode: MERGE_CONFLICT_EXIT_CODE,
		report,
		formatted: formatMergeConflictReport(report, gitRoot),
	});
	console.error(formatMergeConflictReport(report, gitRoot));
	process.exit(MERGE_CONFLICT_EXIT_CODE);
}

run(process.execPath, [packageScriptPath('workspace-release-verify'), '--changed'], { cwd: root });
const automation = ensureGitHubDeployAutomation(root, { dryRun: false });
run('git', ['push', 'origin', 'main'], { cwd: gitRoot });

const summary = {
	ok: true,
	kind: 'success',
	message,
	root,
	repositoryRoot: gitRoot,
	workflowChanged: automation.workflow.changed,
	githubSecretsCreated: automation.secrets.created,
	automationMode: automation.mode,
	versionedPackages: [...versionPlan.bumped],
};
writeSaveReport(summary);

console.log('Treeseed save completed successfully.');
console.log(`Workflow synced: ${automation.workflow.changed ? 'yes' : 'no'}`);
console.log(`GitHub secrets created: ${automation.secrets.created.length}`);
console.log(`Versioned packages: ${[...versionPlan.bumped].join(', ') || 'none'}`);
