import { hashValue } from './crypto';
import type { D1DatabaseLike } from '../../types/cloudflare';
import type { ContactRecordInput } from '../../types/forms';

export async function createContactSubmission(
	db: D1DatabaseLike,
	input: ContactRecordInput,
) {
	const now = new Date().toISOString();
	const ipHash = await hashValue(input.ip || 'unknown');

	await db
		.prepare(
			`INSERT INTO contact_submissions (
				name,
				email,
				organization,
				contact_type,
				subject,
				message,
				user_agent,
				created_at,
				ip_hash
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		)
		.bind(
			input.name,
			input.email,
			input.organization || null,
			input.contactType,
			input.subject,
			input.message,
			input.userAgent || 'unknown user agent',
			now,
			ipHash,
		)
		.run();
}
