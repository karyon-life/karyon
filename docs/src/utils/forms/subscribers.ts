import { hashValue } from './crypto';
import type { D1DatabaseLike } from '../../types/cloudflare';
import type { SubscriberRecordInput } from '../../types/forms';

export async function upsertSubscriber(
	db: D1DatabaseLike,
	input: SubscriberRecordInput,
) {
	const now = new Date().toISOString();
	const ipHash = await hashValue(input.ip || 'unknown');

	await db
		.prepare(
			`INSERT INTO subscribers (email, name, status, source, consent_at, created_at, updated_at, ip_hash)
			 VALUES (?, ?, 'active', ?, ?, ?, ?, ?)
			 ON CONFLICT(email) DO UPDATE SET
			 	name = excluded.name,
			 	status = 'active',
			 	source = excluded.source,
			 	consent_at = excluded.consent_at,
			 	updated_at = excluded.updated_at,
			 	ip_hash = excluded.ip_hash`,
		)
		.bind(input.email, input.name || null, input.source, now, now, now, ipHash)
		.run();
}
