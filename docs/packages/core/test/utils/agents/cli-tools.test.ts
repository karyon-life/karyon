import { describe, expect, it } from 'vitest';
import { buildCopilotAllowToolArgs, normalizeAgentCliOptions } from '../../../src/utils/agents/cli-tools.ts';

describe('agent cli tools', () => {
	it('normalizes and deduplicates allowed tools', () => {
		const cli = normalizeAgentCliOptions({
			model: 'gpt-5.4',
			allowTools: ['shell(git)', 'shell(git)', 'web'],
			additionalArgs: ['--json'],
		});

		expect(cli).toEqual({
			model: 'gpt-5.4',
			allowTools: ['shell(git)', 'web'],
			additionalArgs: ['--json'],
		});
		expect(buildCopilotAllowToolArgs(cli.allowTools)).toEqual([
			'--allow-tool',
			'shell(git)',
			'--allow-tool',
			'web',
		]);
	});

	it('rejects unknown allowed tools', () => {
		expect(() =>
			normalizeAgentCliOptions({
				allowTools: ['shell(rm)'],
			}),
		).toThrow('Invalid agent cli.allowTools entries');
	});

	it('returns safe defaults when cli config is omitted', () => {
		expect(normalizeAgentCliOptions(undefined)).toEqual({
			allowTools: [],
			additionalArgs: [],
		});
	});
});
