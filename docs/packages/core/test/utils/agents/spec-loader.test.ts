import { describe, expect, it } from 'vitest';
import { loadAgentSpecs } from '../../../src/utils/agents/spec-loader.ts';

describe('agent spec loader', () => {
	it('reports invalid handler and missing message permissions as diagnostics', async () => {
		const sdk = {
			listRawAgentSpecs: async () => [
				{
					id: 'broken-agent',
					body: '',
					frontmatter: {
						name: 'Broken Agent',
						slug: 'broken-agent',
						handler: 'ghost',
						enabled: true,
						systemPrompt: 'prompt',
						persona: 'persona',
						cli: { allowTools: ['shell(git)'] },
						triggers: [{ type: 'message', messageTypes: ['task_complete'] }],
						permissions: [{ model: 'knowledge', operations: ['get'] }],
						execution: {
							maxConcurrency: 1,
							timeoutSeconds: 60,
							cooldownSeconds: 0,
							leaseSeconds: 60,
							retryLimit: 1,
							branchPrefix: 'broken',
						},
						outputs: { messageTypes: ['task_verified'], modelMutations: [] },
					},
				},
			],
		} as never;

		const result = await loadAgentSpecs(sdk);

		expect(result.specs).toHaveLength(0);
		expect(result.diagnostics.some((entry) => entry.field === 'handler')).toBe(true);
		expect(result.diagnostics.some((entry) => entry.field === 'permissions')).toBe(true);
	});
});
