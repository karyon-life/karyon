import { afterEach, describe, expect, it } from 'vitest';
import type { AgentTestRuntime } from '../../testing/e2e-harness.ts';
import { createAgentTestRuntime } from '../../testing/e2e-harness.ts';

describe.sequential('disabled agent contracts', () => {
	let runtime: AgentTestRuntime | null = null;

	afterEach(async () => {
		await runtime?.cleanup();
		runtime = null;
	});

	it('loads disabled agent specs, keeps them disabled, and excludes them from active doctor execution', async () => {
		runtime = await createAgentTestRuntime();

		const doctor = await runtime.kernel.doctor();
		const agents = doctor.agents as Array<{ slug: string; enabled: boolean; handler: string }>;
		const disabledAgents = agents.filter((entry) => entry.enabled === false);

		expect(disabledAgents.map((entry) => entry.slug).sort()).toEqual([
			'notifier-agent',
			'releaser-agent',
			'reviewer-agent',
		].sort());
		expect(disabledAgents.every((entry) => typeof entry.handler === 'string' && entry.handler.length > 0)).toBe(true);
		expect(agents.some((entry) => entry.slug === 'planner-agent' && entry.enabled)).toBe(true);
	});
});
