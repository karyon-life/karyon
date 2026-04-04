import { describe, expect, it } from 'vitest';
import {
	parseAgentMessagePayload,
	serializeAgentMessagePayload,
} from '../contracts/messages.ts';

describe('agent message contracts', () => {
	it('serializes and parses priority_updated payloads', () => {
		const payload = serializeAgentMessagePayload('priority_updated', {
			objectiveId: 'build-the-research-hub-surface',
			questionId: 'how-should-objectives-shape-question-prioritization',
			reason: 'Highest-value objective',
			plannerRunId: 'run-1',
		});

		expect(
			parseAgentMessagePayload('priority_updated', JSON.stringify(payload)),
		).toEqual(payload);
	});

	it('rejects invalid architecture_updated payloads', () => {
		expect(() =>
			parseAgentMessagePayload(
				'architecture_updated',
				JSON.stringify({ objectiveId: 'x' }),
			),
		).toThrow('knowledgeId');
	});
});
