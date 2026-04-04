import type { AgentHandlerKind } from '../../../types/agents';
import type { AgentHandler } from '../runtime-types.ts';
import { architectHandler } from './architect.ts';
import { engineerHandler } from './engineer.ts';
import { plannerHandler } from './planner.ts';

export const AGENT_HANDLER_REGISTRY: Partial<Record<AgentHandlerKind, AgentHandler>> = {
	planner: plannerHandler,
	architect: architectHandler,
	engineer: engineerHandler,
};

export function resolveAgentHandler(kind: AgentHandlerKind) {
	const handler = AGENT_HANDLER_REGISTRY[kind];
	if (!handler) {
		throw new Error(`No runtime handler is registered for agent handler "${kind}".`);
	}
	return handler;
}
