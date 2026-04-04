import type { AgentHandlerKind } from '../../../types/agents';
import type { AgentHandler } from '../runtime-types.ts';
import { architectHandler } from './architect.ts';
import { engineerHandler } from './engineer.ts';
import { notifierHandler } from './notifier.ts';
import { plannerHandler } from './planner.ts';
import { releaserHandler } from './releaser.ts';
import { researcherHandler } from './researcher.ts';
import { reviewerHandler } from './reviewer.ts';

export const AGENT_HANDLER_REGISTRY: Partial<Record<AgentHandlerKind, AgentHandler>> = {
	planner: plannerHandler,
	architect: architectHandler,
	engineer: engineerHandler,
	notifier: notifierHandler,
	researcher: researcherHandler,
	reviewer: reviewerHandler,
	releaser: releaserHandler,
};

export function resolveAgentHandler(kind: AgentHandlerKind) {
	const handler = AGENT_HANDLER_REGISTRY[kind];
	if (!handler) {
		throw new Error(`No runtime handler is registered for agent handler "${kind}".`);
	}
	return handler;
}
