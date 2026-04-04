import { describe, expect, it } from 'vitest';
import { MemoryAgentDatabase } from '../d1-store';

describe('memory agent database', () => {
	it('creates and acknowledges queue messages', async () => {
		const database = new MemoryAgentDatabase();
		const created = await database.createMessage({
			type: 'architecture_updated',
			payload: {
				objective: 'build-the-research-hub-surface',
			},
			actor: 'test',
		});

		expect(created.status).toBe('pending');

		await database.ackMessage({ id: created.id, status: 'completed' });
		const found = await database.get({
			model: 'message',
			id: String(created.id),
		});

		expect(found?.status).toBe('completed');
	});

	it('uses expiring content leases to keep picks thread-safe', async () => {
		const database = new MemoryAgentDatabase();
		const first = await database.tryClaimContentLease({
			model: 'question',
			itemKey: 'what-should-a-book-metadata-model-track',
			claimedBy: 'researcher-a',
			leaseSeconds: 60,
		});
		const second = await database.tryClaimContentLease({
			model: 'question',
			itemKey: 'what-should-a-book-metadata-model-track',
			claimedBy: 'researcher-b',
			leaseSeconds: 60,
		});

		expect(first).toBeTruthy();
		expect(second).toBeNull();
	});
});
