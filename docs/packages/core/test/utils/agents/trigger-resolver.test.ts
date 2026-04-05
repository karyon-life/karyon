import { describe, expect, it } from 'vitest';
import type { AgentRuntimeSpec } from '../../../src/types/agents';
import { resolveTriggerDecision } from '../../../src/utils/agents/kernel/trigger-resolver.ts';

function makeAgent(overrides: Partial<AgentRuntimeSpec>): AgentRuntimeSpec {
	return {
		slug: 'planner-agent',
		handler: 'planner',
		enabled: true,
		systemPrompt: 'prompt',
		persona: 'persona',
		cli: {},
		triggers: [{ type: 'schedule', cron: '* * * * *', runOnStart: true }],
		permissions: [],
		execution: {
			maxConcurrency: 1,
			timeoutSeconds: 60,
			cooldownSeconds: 30,
			leaseSeconds: 60,
			retryLimit: 1,
			branchPrefix: 'planner',
		},
		outputs: {
			messageTypes: [],
			modelMutations: [],
		},
		...overrides,
	};
}

describe('trigger resolver', () => {
	it('blocks when the agent is already running', async () => {
		const decision = await resolveTriggerDecision({
			agent: makeAgent({}),
			isRunning: true,
			lastRunAt: 0,
			sdk: {
				claimMessage: async () => ({ payload: null }),
			} as never,
		});

		expect(decision.kind).toBe('blocked_by_concurrency');
	});

	it('returns no_message_available for message triggers with no message', async () => {
		const decision = await resolveTriggerDecision({
			agent: makeAgent({
				triggers: [{ type: 'message', messageTypes: ['architecture_updated'] }],
			}),
			isRunning: false,
			lastRunAt: 0,
			sdk: {
				claimMessage: async () => ({ payload: null }),
			} as never,
		});

		expect(decision.kind).toBe('no_message_available');
	});

	it('returns blocked_by_cooldown when schedule trigger is still cooling down', async () => {
		const decision = await resolveTriggerDecision({
			agent: makeAgent({}),
			isRunning: false,
			lastRunAt: Date.now(),
			sdk: {
				claimMessage: async () => ({ payload: null }),
			} as never,
		});

		expect(decision.kind).toBe('blocked_by_cooldown');
	});

	it('prefers message triggers over schedule triggers', async () => {
		const decision = await resolveTriggerDecision({
			agent: makeAgent({
				triggers: [
					{ type: 'schedule', cron: '* * * * *', runOnStart: true },
					{ type: 'message', messageTypes: ['architecture_updated'] },
				],
			}),
			isRunning: false,
			lastRunAt: 0,
			sdk: {
				claimMessage: async () => ({
					payload: {
						id: 1,
						type: 'architecture_updated',
						payloadJson: '{}',
					},
				}),
			} as never,
		});

		expect(decision.kind).toBe('ready');
		expect(decision.invocation?.kind).toBe('message');
	});

	it('uses follow triggers when message triggers are empty and new activity exists', async () => {
		const decision = await resolveTriggerDecision({
			agent: makeAgent({
				triggers: [
					{ type: 'message', messageTypes: ['architecture_updated'] },
					{ type: 'follow', models: ['knowledge'] },
				],
				permissions: [
					{ model: 'message', operations: ['pick', 'update', 'search', 'get'] },
					{ model: 'knowledge', operations: ['follow', 'search', 'get'] },
				],
			}),
			isRunning: false,
			lastRunAt: 0,
			sdk: {
				claimMessage: async () => ({ payload: null }),
				getCursor: async () => ({ payload: '2026-04-01T00:00:00.000Z' }),
				follow: async () => ({ payload: { items: [{ id: 'k1' }], since: '2026-04-01T00:00:00.000Z' } }),
			} as never,
		});

		expect(decision.kind).toBe('ready');
		expect(decision.invocation?.kind).toBe('follow');
		expect(decision.invocation?.followModels).toEqual(['knowledge']);
	});
});
