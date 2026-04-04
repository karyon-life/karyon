import { describe, expect, it } from 'vitest';
import type { AgentRuntimeSpec } from '../../../types/agents';
import { resolveTriggerDecision } from '../kernel/trigger-resolver.ts';

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
});
