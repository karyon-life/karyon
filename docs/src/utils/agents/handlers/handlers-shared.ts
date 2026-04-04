import type { AgentExecutionResult } from '../runtime-types.ts';

export function waiting(summary: string): AgentExecutionResult {
	return {
		status: 'waiting',
		summary,
	};
}
