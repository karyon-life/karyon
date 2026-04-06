import type { AgentHandlerKind } from '@treeseed/core/types/agents';
import type { AgentHandler } from './runtime-types';

export declare function defineAgentHandlerRegistry(
	registry: Partial<Record<AgentHandlerKind, AgentHandler>>,
): Partial<Record<AgentHandlerKind, AgentHandler>>;

export declare function resolveAgentHandlerFromRegistry(
	registry: Partial<Record<AgentHandlerKind, AgentHandler>>,
	kind: AgentHandlerKind,
): AgentHandler;
