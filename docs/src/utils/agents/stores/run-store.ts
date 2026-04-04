import type { SdkRecordRunRequest, SdkRunEntity } from '../sdk-types';
import { SqliteStoreBase, nowIso, toSqlValue } from './helpers.ts';

export function runFromRecord(row: Record<string, unknown>): SdkRunEntity {
	return {
		runId: String(row.runId ?? row.run_id ?? ''),
		agentSlug: String(row.agentSlug ?? row.agent_slug ?? ''),
		triggerSource: String(row.triggerSource ?? row.trigger_source ?? ''),
		status: String(row.status ?? ''),
		selectedItemKey: row.selectedItemKey !== undefined && row.selectedItemKey !== null ? String(row.selectedItemKey) : row.selected_item_key !== undefined && row.selected_item_key !== null ? String(row.selected_item_key) : null,
		selectedMessageId: row.selectedMessageId !== undefined && row.selectedMessageId !== null ? Number(row.selectedMessageId) : row.selected_message_id !== undefined && row.selected_message_id !== null ? Number(row.selected_message_id) : null,
		branchName: row.branchName !== undefined && row.branchName !== null ? String(row.branchName) : row.branch_name !== undefined && row.branch_name !== null ? String(row.branch_name) : null,
		prUrl: row.prUrl !== undefined && row.prUrl !== null ? String(row.prUrl) : row.pr_url !== undefined && row.pr_url !== null ? String(row.pr_url) : null,
		summary: row.summary !== undefined && row.summary !== null ? String(row.summary) : null,
		error: row.error !== undefined && row.error !== null ? String(row.error) : null,
		startedAt: String(row.startedAt ?? row.started_at ?? nowIso()),
		finishedAt: row.finishedAt !== undefined && row.finishedAt !== null ? String(row.finishedAt) : row.finished_at !== undefined && row.finished_at !== null ? String(row.finished_at) : null,
		errorCategory: row.errorCategory !== undefined && row.errorCategory !== null ? String(row.errorCategory) : row.error_category !== undefined && row.error_category !== null ? String(row.error_category) : null,
		handlerKind: row.handlerKind !== undefined && row.handlerKind !== null ? String(row.handlerKind) : row.handler_kind !== undefined && row.handler_kind !== null ? String(row.handler_kind) : null,
		triggerKind: row.triggerKind !== undefined && row.triggerKind !== null ? String(row.triggerKind) : row.trigger_kind !== undefined && row.trigger_kind !== null ? String(row.trigger_kind) : null,
		commitSha: row.commitSha !== undefined && row.commitSha !== null ? String(row.commitSha) : row.commit_sha !== undefined && row.commit_sha !== null ? String(row.commit_sha) : null,
		changedPaths: Array.isArray(row.changedPaths) ? row.changedPaths.map(String) : row.changed_paths ? JSON.parse(String(row.changed_paths)) : [],
	};
}

export class RunStore extends SqliteStoreBase {
	async record(request: SdkRecordRunRequest) {
		const run = runFromRecord(request.run);
		await this.execute(
			`INSERT OR REPLACE INTO agent_runs (run_id, agent_slug, trigger_source, status, selected_item_key, selected_message_id, branch_name, pr_url, summary, error, started_at, finished_at) VALUES (${toSqlValue(run.runId)}, ${toSqlValue(run.agentSlug)}, ${toSqlValue(run.triggerSource)}, ${toSqlValue(run.status)}, ${toSqlValue(run.selectedItemKey)}, ${toSqlValue(run.selectedMessageId)}, ${toSqlValue(run.branchName)}, ${toSqlValue(run.prUrl)}, ${toSqlValue(run.summary)}, ${toSqlValue(run.error)}, ${toSqlValue(run.startedAt)}, ${toSqlValue(run.finishedAt)})`,
		);
		return run;
	}
}
