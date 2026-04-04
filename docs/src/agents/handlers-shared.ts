import type { AgentExecutionResult } from '../utils/agents/runtime-types.ts';

export function waiting(summary: string): AgentExecutionResult {
	return {
		status: 'waiting',
		summary,
	};
}
