import type { AgentHandlerKind } from '../types/agents';
import type { AgentHandler } from '../utils/agents/runtime-types';

export declare function defineAgentHandlerRegistry(
	registry: Partial<Record<AgentHandlerKind, AgentHandler>>,
): Partial<Record<AgentHandlerKind, AgentHandler>>;

export declare function resolveAgentHandlerFromRegistry(
	registry: Partial<Record<AgentHandlerKind, AgentHandler>>,
	kind: AgentHandlerKind,
): AgentHandler;
