import { afterEach, describe, expect, it } from 'vitest';
import { parseAgentMessagePayload } from '../../contracts/messages.ts';
import type { AgentTestRuntime } from '../../testing/e2e-harness.ts';
import { createAgentTestRuntime } from '../../testing/e2e-harness.ts';

describe.sequential('agent mvp sequence e2e', () => {
	let runtime: AgentTestRuntime | null = null;

	afterEach(async () => {
		await runtime?.cleanup();
		runtime = null;
	});

	it('runs planner -> architect -> engineer end to end in one kernel cycle', async () => {
		runtime = await createAgentTestRuntime();
		await runtime.seedObjectives([{ slug: 'sequence-objective' }]);
		await runtime.seedQuestions([
			{
				slug: 'sequence-question',
				relatedObjectives: ['sequence-objective'],
			},
		]);

		const results = await runtime.runCycle();
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();
		const leases = await runtime.readContentLeases();
		const artifacts = await runtime.readSandboxArtifacts();

		expect(results).toHaveLength(3);
		expect((results as Array<{ slug: string }>).map((entry) => entry.slug)).toEqual([
			'planner-agent',
			'architecture-agent',
			'engineer-agent',
		]);
		expect(messages.map((entry) => entry.type)).toEqual([
			'priority_updated',
			'architecture_updated',
			'task_complete',
		]);
		expect(messages.map((entry) => entry.status)).toEqual([
			'completed',
			'completed',
			'pending',
		]);
		expect(parseAgentMessagePayload('priority_updated', messages[0]!.payloadJson)).toMatchObject({
			objectiveId: 'sequence-objective',
			questionId: 'sequence-question',
		});
		expect(parseAgentMessagePayload('architecture_updated', messages[1]!.payloadJson)).toMatchObject({
			objectiveId: 'sequence-objective',
		});
		expect(parseAgentMessagePayload('task_complete', messages[2]!.payloadJson).changedTargets).toHaveLength(1);
		expect(runs).toHaveLength(3);
		expect(runs.map((entry) => entry.agentSlug)).toEqual([
			'planner-agent',
			'architecture-agent',
			'engineer-agent',
		]);
		expect(runs.every((entry) => entry.status === 'completed')).toBe(true);
		expect(artifacts).toHaveLength(1);
		expect(leases).toEqual([]);
	});
});
