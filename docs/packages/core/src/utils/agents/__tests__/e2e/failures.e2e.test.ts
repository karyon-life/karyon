import { afterEach, describe, expect, it } from 'vitest';
import type { AgentExecutionAdapter, AgentMutationAdapter } from '../../runtime-types.ts';
import { parseAgentMessagePayload, serializeAgentMessagePayload } from '../../contracts/messages.ts';
import type { AgentTestRuntime } from '../../testing/e2e-harness.ts';
import { createAgentTestRuntime } from '../../testing/e2e-harness.ts';

describe.sequential('agent failure e2e', () => {
	let runtime: AgentTestRuntime | null = null;

	afterEach(async () => {
		await runtime?.cleanup();
		runtime = null;
	});

	it('returns waiting when planner has no objective to prioritize', async () => {
		runtime = await createAgentTestRuntime();
		await runtime.clearModelContent('objective');
		await runtime.clearModelContent('question');

		const result = await runtime.runAgent('planner-agent');
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();

		expect(result).toMatchObject({
			status: 'waiting',
		});
		expect(messages).toEqual([]);
		expect(runs).toHaveLength(1);
		expect(runs[0]).toMatchObject({
			agentSlug: 'planner-agent',
			status: 'waiting',
			summary: 'Planner found no questions or objectives to prioritize.',
		});
	});

	it('fails fast on invalid architect input payload and records the error category', async () => {
		runtime = await createAgentTestRuntime();
		await runtime.seedMessages([
			{
				type: 'objective_priority_updated',
				payload: { objectiveId: '', reason: 'invalid', plannerRunId: 'planner-run-invalid' },
			},
		]);

		await expect(runtime.runAgent('architecture-agent')).rejects.toThrow('Invalid objectiveId');
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();

		expect(messages[0]).toMatchObject({
			type: 'objective_priority_updated',
			status: 'failed',
		});
		expect(runs[0]).toMatchObject({
			agentSlug: 'architecture-agent',
			status: 'failed',
			errorCategory: 'sdk_error',
		});
	});

	it('emits task_failed when the referenced knowledge cannot be loaded', async () => {
		runtime = await createAgentTestRuntime();
		await runtime.seedMessages([
			{
				type: 'architecture_updated',
				payload: serializeAgentMessagePayload('architecture_updated', {
					objectiveId: 'missing-knowledge-objective',
					knowledgeId: 'missing-knowledge',
					architectRunId: 'architect-run-missing',
				}),
			},
		]);

		const result = await runtime.runAgent('engineer-agent');
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();

		expect(result).toMatchObject({
			status: 'failed',
		});
		expect(messages).toHaveLength(2);
		expect(messages[0]?.status).toBe('failed');
		expect(messages[1]?.type).toBe('task_failed');
		expect(parseAgentMessagePayload('task_failed', messages[1]!.payloadJson)).toMatchObject({
			failureSummary: 'Knowledge missing-knowledge could not be loaded.',
		});
		expect(runs[0]).toMatchObject({
			agentSlug: 'engineer-agent',
			status: 'failed',
			errorCategory: 'sdk_error',
		});
	});

	it('emits task_failed with execution_error when execution fails', async () => {
		const failingExecution: AgentExecutionAdapter = {
			runTask: async () => ({
				status: 'failed',
				summary: 'Stub execution failure.',
				stderr: 'execution failed',
				errorCategory: 'execution_error',
			}),
		};
		runtime = await createAgentTestRuntime({
			execution: failingExecution,
		});
		await runtime.seedKnowledge([{ slug: 'execution-failure-knowledge' }]);
		await runtime.seedMessages([
			{
				type: 'architecture_updated',
				payload: serializeAgentMessagePayload('architecture_updated', {
					objectiveId: 'execution-failure-objective',
					knowledgeId: 'execution-failure-knowledge',
					architectRunId: 'architect-run-execution-failure',
				}),
			},
		]);

		const result = await runtime.runAgent('engineer-agent');
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();

		expect(result).toMatchObject({
			status: 'failed',
		});
		expect(messages[1]?.type).toBe('task_failed');
		expect(runs[0]).toMatchObject({
			errorCategory: 'execution_error',
			status: 'failed',
		});
	});

	it('emits task_failed with mutation_error when artifact writing fails', async () => {
		const failingMutations: AgentMutationAdapter = {
			writeArtifact: async () => {
				throw new Error('artifact write failed');
			},
		};
		runtime = await createAgentTestRuntime({
			mutations: failingMutations,
		});
		await runtime.seedKnowledge([{ slug: 'mutation-failure-knowledge' }]);
		await runtime.seedMessages([
			{
				type: 'architecture_updated',
				payload: serializeAgentMessagePayload('architecture_updated', {
					objectiveId: 'mutation-failure-objective',
					knowledgeId: 'mutation-failure-knowledge',
					architectRunId: 'architect-run-mutation-failure',
				}),
			},
		]);

		const result = await runtime.runAgent('engineer-agent');
		const messages = await runtime.readMessages();
		const runs = await runtime.readRunLogs();

		expect(result).toMatchObject({
			status: 'failed',
		});
		expect(messages[1]?.type).toBe('task_failed');
		expect(runs[0]).toMatchObject({
			errorCategory: 'mutation_error',
			status: 'failed',
		});
	});

	it('returns waiting when architect has no objective priority message to process', async () => {
		runtime = await createAgentTestRuntime();

		const result = await runtime.runAgent('architecture-agent');
		const messages = await runtime.readMessages();

		expect(result).toMatchObject({
			status: 'waiting',
		});
		expect(messages).toEqual([]);
		expect(await runtime.readRunLogs()).toEqual([]);
	});

	it('allows only one claimant for the same architecture_updated message', async () => {
		runtime = await createAgentTestRuntime();
		await runtime.seedMessages([
			{
				type: 'architecture_updated',
				payload: serializeAgentMessagePayload('architecture_updated', {
					objectiveId: 'claim-conflict-objective',
					knowledgeId: 'claim-conflict-knowledge',
					architectRunId: 'architect-run-conflict',
				}),
			},
		]);

		const claimed = await runtime.claimMessage(['architecture_updated'], 'first-claimant');
		const result = await runtime.runAgent('engineer-agent');
		const messages = await runtime.readMessages();

		expect(claimed?.claimedBy).toBe('first-claimant');
		expect(result).toMatchObject({
			status: 'waiting',
		});
		expect(messages).toHaveLength(1);
		expect(messages[0]?.status).toBe('claimed');
	});
});
