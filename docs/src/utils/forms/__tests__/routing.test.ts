import { describe, expect, it } from 'vitest';
import { resolveContactRecipientsFromMap } from '../routing-core';

describe('contact routing resolution', () => {
	it('prefers a specific route over the default recipients', () => {
		const recipients = resolveContactRecipientsFromMap(
			{
				default: ['default@example.com'],
				feedback: ['feedback@example.com'],
			},
			'feedback',
		);

		expect(recipients).toEqual(['feedback@example.com']);
	});

	it('falls back to default recipients', () => {
		const recipients = resolveContactRecipientsFromMap(
			{
				default: ['default@example.com'],
			},
			'issue',
		);

		expect(recipients).toEqual(['default@example.com']);
	});
});
