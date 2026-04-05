import { describe, expect, it } from 'vitest';
import { AGENT_HANDLER_KINDS } from '../../../types/agents';
import { AGENT_HANDLER_REGISTRY, resolveAgentHandler } from '../../../agents/registry.ts';

describe('agent handler registry', () => {
	it('registers a runtime handler for every declared agent handler kind', () => {
		expect(Object.keys(AGENT_HANDLER_REGISTRY).sort()).toEqual([...AGENT_HANDLER_KINDS].sort());
		for (const kind of AGENT_HANDLER_KINDS) {
			expect(resolveAgentHandler(kind).kind).toBe(kind);
		}
	});
});
