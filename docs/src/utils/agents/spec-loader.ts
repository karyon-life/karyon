import type { AgentRuntimeSpec } from '../../types/agents';
import { AgentSdk } from './sdk.ts';

export async function loadActiveAgentSpecs(sdk: AgentSdk) {
	return sdk.listAgentSpecs();
}

export function summarizeAgentSpec(agent: AgentRuntimeSpec) {
	return {
		slug: agent.slug,
		handler: agent.handler,
		enabled: agent.enabled,
		triggers: agent.triggers.map((trigger) => trigger.type),
	};
}
