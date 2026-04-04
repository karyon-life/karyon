import { afterEach, describe, expect, it } from 'vitest';
import { parseAgentMessagePayload, serializeAgentMessagePayload } from '../../contracts/messages.ts';
import type { AgentTestRuntime } from '../../testing/e2e-harness.ts';
import { createAgentTestRuntime } from '../../testing/e2e-harness.ts';

describe.sequential('architecture agent e2e', () => {
	let runtime: AgentTestRuntime | null = null;

	afterEach(async () => {
		await runtime?.cleanup();
		runtime = null;
	});

	it('claims planner output, creates knowledge, emits architecture_updated, and releases leases', async () => {
		runtime = await createAgentTestRuntime();
		await runtime.seedObjectives([{ slug: 'architecture-e2e-objective' }]);
		await runtime.seedMessages([
			{
				type: 'priority_updated',
				payload: serializeAgentMessagePayload('priority_updated', {
					objectiveId: 'architecture-e2e-objective',
					questionId: null,
					reason: 'Architecture should proceed.',
					plannerRunId: 'planner-run-1',
				}),
			},
		]);

		const result = await runtime.runAgent('architecture-agent');
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();
		const leases = await runtime.readContentLeases();

		expect(result).toMatchObject({
			status: 'completed',
		});
		expect(messages).toHaveLength(2);
		expect(messages[0]).toMatchObject({
			type: 'priority_updated',
			status: 'completed',
		});
		expect(messages[1]?.type).toBe('architecture_updated');
		expect(parseAgentMessagePayload('architecture_updated', messages[1]!.payloadJson)).toMatchObject({
			objectiveId: 'architecture-e2e-objective',
		});
		expect(runs).toHaveLength(1);
		expect(runs[0]).toMatchObject({
			agentSlug: 'architecture-agent',
			handlerKind: 'architect',
			triggerKind: 'message',
			triggerSource: 'message',
			claimedMessageId: messages[0]?.id ?? null,
			status: 'completed',
		});
		expect(runs[0]?.summary).toContain('Architect created knowledge');
		expect(leases).toEqual([]);
	});
});
