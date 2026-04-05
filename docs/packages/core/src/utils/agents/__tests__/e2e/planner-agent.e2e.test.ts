import { afterEach, describe, expect, it } from 'vitest';
import { parseAgentMessagePayload } from '../../contracts/messages.ts';
import type { AgentTestRuntime } from '../../testing/e2e-harness.ts';
import { createAgentTestRuntime } from '../../testing/e2e-harness.ts';

describe.sequential('planner agent e2e', () => {
	let runtime: AgentTestRuntime | null = null;

	afterEach(async () => {
		await runtime?.cleanup();
		runtime = null;
	});

	it('creates question and objective priority messages and a run log without mutating the main checkout', async () => {
		runtime = await createAgentTestRuntime();
		await runtime.seedObjectives([{ slug: 'planner-e2e-objective' }]);
		await runtime.seedQuestions([
			{
				slug: 'planner-e2e-question',
				relatedObjectives: ['planner-e2e-objective'],
			},
		]);

		const result = await runtime.runAgent('planner-agent');
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();
		const artifacts = await runtime.readSandboxArtifacts();

		expect(result).toMatchObject({
			status: 'completed',
		});
		expect(messages).toHaveLength(2);
		expect(messages.map((entry) => entry.type)).toEqual([
			'question_priority_updated',
			'objective_priority_updated',
		]);
		expect(messages.every((entry) => entry.status === 'pending')).toBe(true);
		expect(parseAgentMessagePayload('question_priority_updated', messages[0]!.payloadJson)).toMatchObject({
			questionId: 'planner-e2e-question',
		});
		expect(parseAgentMessagePayload('objective_priority_updated', messages[1]!.payloadJson)).toMatchObject({
			objectiveId: 'planner-e2e-objective',
		});
		expect(runs).toHaveLength(1);
		expect(runs[0]).toMatchObject({
			agentSlug: 'planner-agent',
			handlerKind: 'planner',
			triggerKind: 'manual',
			triggerSource: 'manual',
			status: 'completed',
			claimedMessageId: null,
			summary: 'Planner prioritized 1 question(s) and 1 objective(s).',
		});
		expect(artifacts).toEqual([]);
	});
});
