import crypto from 'node:crypto';
import type { SdkLeaseReleaseRequest } from '../sdk-types';
import { SqliteStoreBase, nowIso, toSqlValue } from './helpers.ts';

export interface LeaseClaimInput {
	model: string;
	itemKey: string;
	claimedBy: string;
	leaseSeconds: number;
}

export class LeaseStore extends SqliteStoreBase {
	async tryClaim(input: LeaseClaimInput) {
		const existing = await this.selectFirst(
			`SELECT * FROM content_leases WHERE model = ${toSqlValue(input.model)} AND item_key = ${toSqlValue(input.itemKey)} LIMIT 1`,
		);
		if (existing && new Date(String(existing.lease_expires_at ?? 0)).valueOf() > Date.now()) {
			return null;
		}
		const token = crypto.randomUUID();
		await this.execute(
			`INSERT OR REPLACE INTO content_leases (model, item_key, claimed_by, claimed_at, lease_expires_at, token) VALUES (${toSqlValue(input.model)}, ${toSqlValue(input.itemKey)}, ${toSqlValue(input.claimedBy)}, ${toSqlValue(nowIso())}, ${toSqlValue(new Date(Date.now() + input.leaseSeconds * 1000).toISOString())}, ${toSqlValue(token)})`,
		);
		return token;
	}

	async release(request: SdkLeaseReleaseRequest) {
		await this.execute(
			`DELETE FROM content_leases WHERE model = ${toSqlValue(request.model)} AND item_key = ${toSqlValue(request.itemKey)}`,
		);
	}

	async releaseAll() {
		const rows = await this.selectAll('SELECT COUNT(*) AS count FROM content_leases');
		await this.execute('DELETE FROM content_leases');
		return Number(rows[0]?.count ?? 0);
	}
}
