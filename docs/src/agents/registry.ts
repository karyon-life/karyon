import type { AgentHandlerKind } from '@treeseed/core/types/agents';
import type { AgentHandler } from '@treeseed/core/utils/agents/runtime-types';
import {
	defineAgentHandlerRegistry,
	resolveAgentHandlerFromRegistry,
} from '@treeseed/core/agents/registry-helper';
import { architectHandler } from './architect.ts';
import { engineerHandler } from './engineer.ts';
import { notifierHandler } from './notifier.ts';
import { plannerHandler } from './planner.ts';
import { releaserHandler } from './releaser.ts';
import { researcherHandler } from './researcher.ts';
import { reviewerHandler } from './reviewer.ts';

export const AGENT_HANDLER_REGISTRY: Partial<Record<AgentHandlerKind, AgentHandler>> =
	defineAgentHandlerRegistry({
	planner: plannerHandler,
	architect: architectHandler,
	engineer: engineerHandler,
	notifier: notifierHandler,
	researcher: researcherHandler,
	reviewer: reviewerHandler,
	releaser: releaserHandler,
	});

export function resolveAgentHandler(kind: AgentHandlerKind) {
	return resolveAgentHandlerFromRegistry(AGENT_HANDLER_REGISTRY, kind);
}
