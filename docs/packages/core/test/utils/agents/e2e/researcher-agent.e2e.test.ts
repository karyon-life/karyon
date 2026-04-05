import { afterEach, describe, expect, it } from 'vitest';
import { parseAgentMessagePayload, serializeAgentMessagePayload } from '../../../../src/utils/agents/contracts/messages.ts';
import type { AgentTestRuntime } from '../../../../src/utils/agents/testing/e2e-harness.ts';
import { createAgentTestRuntime } from '../../../../src/utils/agents/testing/e2e-harness.ts';

describe.sequential('researcher agent e2e', () => {
	let runtime: AgentTestRuntime | null = null;

	afterEach(async () => {
		await runtime?.cleanup();
		runtime = null;
	});

	it('claims question priority output, creates research knowledge, and emits research messages', async () => {
		runtime = await createAgentTestRuntime();
		await runtime.seedQuestions([{ slug: 'researcher-e2e-question' }]);
		await runtime.seedMessages([
			{
				type: 'question_priority_updated',
				payload: serializeAgentMessagePayload('question_priority_updated', {
					questionId: 'researcher-e2e-question',
					reason: 'Research should proceed.',
					plannerRunId: 'planner-run-1',
				}),
			},
		]);

		const result = await runtime.runAgent('researcher-agent');
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();

		expect(result).toMatchObject({
			status: 'completed',
		});
		expect(messages).toHaveLength(3);
		expect(messages[0]).toMatchObject({
			type: 'question_priority_updated',
			status: 'completed',
		});
		expect(messages[1]?.type).toBe('research_started');
		expect(messages[2]?.type).toBe('research_completed');
		expect(parseAgentMessagePayload('research_completed', messages[2]!.payloadJson)).toMatchObject({
			questionId: 'researcher-e2e-question',
		});
		expect(runs).toHaveLength(1);
		expect(runs[0]).toMatchObject({
			agentSlug: 'researcher-agent',
			handlerKind: 'researcher',
			triggerKind: 'message',
			triggerSource: 'message',
			claimedMessageId: messages[0]?.id ?? null,
			status: 'completed',
		});
	});
});
