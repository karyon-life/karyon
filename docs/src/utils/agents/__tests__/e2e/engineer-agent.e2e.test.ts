import { afterEach, describe, expect, it } from 'vitest';
import { parseAgentMessagePayload, serializeAgentMessagePayload } from '../../contracts/messages.ts';
import type { AgentTestRuntime } from '../../testing/e2e-harness.ts';
import { createAgentTestRuntime } from '../../testing/e2e-harness.ts';

describe.sequential('engineer agent e2e', () => {
	let runtime: AgentTestRuntime | null = null;

	afterEach(async () => {
		await runtime?.cleanup();
		runtime = null;
	});

	it('claims architecture work, invokes execution, writes a sandbox artifact, and emits task_complete', async () => {
		runtime = await createAgentTestRuntime();
		await runtime.seedKnowledge([
			{
				slug: 'engineer-e2e-knowledge',
				title: 'Engineer E2E Knowledge',
			},
		]);
		await runtime.seedMessages([
			{
				type: 'architecture_updated',
				payload: serializeAgentMessagePayload('architecture_updated', {
					objectiveId: 'engineer-e2e-objective',
					knowledgeId: 'engineer-e2e-knowledge',
					architectRunId: 'architect-run-1',
				}),
			},
		]);

		const result = await runtime.runAgent('engineer-agent');
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();
		const artifacts = await runtime.readSandboxArtifacts();

		expect(result).toMatchObject({
			status: 'completed',
		});
		expect(messages).toHaveLength(2);
		expect(messages[0]).toMatchObject({
			type: 'architecture_updated',
			status: 'completed',
		});
		expect(messages[1]?.type).toBe('task_complete');
		const payload = parseAgentMessagePayload('task_complete', messages[1]!.payloadJson);
		expect(payload.changedTargets.length).toBe(1);
		expect(payload.branchName).toContain('engineer/');
		expect(runs).toHaveLength(1);
		expect(runs[0]).toMatchObject({
			agentSlug: 'engineer-agent',
			handlerKind: 'engineer',
			triggerKind: 'message',
			triggerSource: 'message',
			claimedMessageId: messages[0]?.id ?? null,
			status: 'completed',
		});
		expect(runs[0]?.branchName).toContain('engineer/');
		expect(runs[0]?.changedPaths).toHaveLength(1);
		expect(runs[0]?.commitSha).toBeTruthy();
		expect(artifacts).toHaveLength(1);
		expect(artifacts[0]?.content).toContain('# Engineer Run Artifact');
	});
});
