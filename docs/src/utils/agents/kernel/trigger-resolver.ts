import crypto from 'node:crypto';
import type { AgentRuntimeSpec } from '../../../types/agents';
import type { ScopedAgentSdk } from '../sdk.ts';
import type { AgentTriggerInvocation } from '../runtime-types.ts';

export type TriggerDecisionKind =
	| 'ready'
	| 'skip'
	| 'blocked_by_cooldown'
	| 'blocked_by_concurrency'
	| 'no_message_available'
	| 'no_trigger_available';

export interface TriggerDecision {
	kind: TriggerDecisionKind;
	invocation?: AgentTriggerInvocation;
	reason?: string;
}

export interface TriggerResolverInput {
	agent: AgentRuntimeSpec;
	mode?: 'auto' | 'manual';
	isRunning: boolean;
	lastRunAt?: number;
	sdk: ScopedAgentSdk;
}

export async function resolveTriggerDecision(input: TriggerResolverInput): Promise<TriggerDecision> {
	if (input.isRunning) {
		return {
			kind: 'blocked_by_concurrency',
			reason: `Agent ${input.agent.slug} is already running.`,
		};
	}

	const mode = input.mode ?? 'auto';
	const messageTrigger = input.agent.triggers.find((trigger) => trigger.type === 'message');
	if (messageTrigger) {
		const claimed = await input.sdk.claimMessage({
			workerId: `${input.agent.slug}-${crypto.randomUUID()}`,
			messageTypes: messageTrigger.messageTypes ?? [],
			leaseSeconds: input.agent.execution.leaseSeconds,
		});
		if (claimed.payload) {
			return {
				kind: 'ready',
				invocation: {
					kind: 'message',
					source: 'message',
					trigger: messageTrigger,
					message: claimed.payload,
				},
			};
		}
		if (messageTrigger.messageTypes?.length) {
			return {
				kind: 'no_message_available',
				reason: `No matching messages for ${input.agent.slug}.`,
			};
		}
	}

	const scheduleTrigger = input.agent.triggers.find((trigger) => trigger.type === 'schedule');
	if (!scheduleTrigger) {
		return {
			kind: 'no_trigger_available',
			reason: `No runnable triggers defined for ${input.agent.slug}.`,
		};
	}

	if (mode === 'manual') {
		return {
			kind: 'ready',
			invocation: {
				kind: 'manual',
				source: 'manual',
				trigger: scheduleTrigger,
			},
		};
	}

	const cooldownMs = input.agent.execution.cooldownSeconds * 1000;
	if ((input.lastRunAt ?? 0) > 0 && Date.now() - (input.lastRunAt ?? 0) < cooldownMs) {
		return {
			kind: 'blocked_by_cooldown',
			reason: `Agent ${input.agent.slug} is cooling down.`,
		};
	}

	return {
		kind: 'ready',
		invocation: {
			kind: scheduleTrigger.runOnStart ? 'startup' : 'schedule',
			source: scheduleTrigger.runOnStart ? 'startup' : 'schedule',
			trigger: scheduleTrigger,
		},
	};
}
