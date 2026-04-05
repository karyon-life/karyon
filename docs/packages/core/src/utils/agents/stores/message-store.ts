import type { SdkAckMessageRequest, SdkClaimMessageRequest, SdkCreateMessageRequest, SdkMessageEntity, SdkSearchRequest } from '../sdk-types';
import { SqliteStoreBase, nowIso, toSqlValue, type DatabaseRow } from './helpers.ts';

export function messageFromRow(row: DatabaseRow): SdkMessageEntity {
	return {
		id: Number(row.id),
		type: String(row.type ?? ''),
		status: String(row.status ?? 'pending'),
		payloadJson: String(row.payload_json ?? row.payloadJson ?? '{}'),
		relatedModel: row.related_model ? String(row.related_model) : row.relatedModel ? String(row.relatedModel) : null,
		relatedId: row.related_id ? String(row.related_id) : row.relatedId ? String(row.relatedId) : null,
		priority: Number(row.priority ?? 0),
		availableAt: String(row.available_at ?? row.availableAt ?? nowIso()),
		claimedBy: row.claimed_by ? String(row.claimed_by) : row.claimedBy ? String(row.claimedBy) : null,
		claimedAt: row.claimed_at ? String(row.claimed_at) : row.claimedAt ? String(row.claimedAt) : null,
		leaseExpiresAt: row.lease_expires_at ? String(row.lease_expires_at) : row.leaseExpiresAt ? String(row.leaseExpiresAt) : null,
		attempts: Number(row.attempts ?? 0),
		maxAttempts: Number(row.max_attempts ?? row.maxAttempts ?? 3),
		createdAt: String(row.created_at ?? row.createdAt ?? nowIso()),
		updatedAt: String(row.updated_at ?? row.updatedAt ?? nowIso()),
	};
}

function buildFilterSql(filters: SdkSearchRequest['filters'] = []) {
	return filters?.length
		? `WHERE ${filters
			.map((filter) => {
				switch (filter.op) {
					case 'eq':
						return `${filter.field} = ${toSqlValue(filter.value)}`;
					case 'in':
						return `${filter.field} IN (${(Array.isArray(filter.value) ? filter.value : [filter.value]).map(toSqlValue).join(', ')})`;
					case 'updated_since':
						return `${filter.field} >= ${toSqlValue(filter.value)}`;
					default:
						return `${filter.field} LIKE ${toSqlValue(`%${String(filter.value ?? '')}%`)}`;
				}
			})
			.join(' AND ')}`
		: '';
}

function buildOrderSql(sort: SdkSearchRequest['sort'] = []) {
	return sort?.length
		? `ORDER BY ${sort.map((entry) => `${entry.field} ${entry.direction === 'asc' ? 'ASC' : 'DESC'}`).join(', ')}`
		: '';
}

export class MessageStore extends SqliteStoreBase {
	async getById(id: number) {
		const row = await this.selectFirst(`SELECT * FROM messages WHERE id = ${id} LIMIT 1`);
		return row ? messageFromRow(row) : null;
	}

	async search(request: SdkSearchRequest) {
		const sql = [
			'SELECT * FROM messages',
			buildFilterSql(request.filters),
			buildOrderSql(request.sort),
			request.limit ? `LIMIT ${request.limit}` : '',
		].filter(Boolean).join(' ');
		const rows = await this.selectAll(sql);
		return rows.map(messageFromRow);
	}

	async claim(request: SdkClaimMessageRequest) {
		const typeClause = request.messageTypes?.length
			? ` AND type IN (${request.messageTypes.map(toSqlValue).join(', ')})`
			: '';
		const row = await this.selectFirst(
			`SELECT * FROM messages WHERE status IN ('pending', 'failed') AND available_at <= ${toSqlValue(nowIso())}${typeClause} ORDER BY priority DESC, available_at ASC LIMIT 1`,
		);
		if (!row) {
			return null;
		}
		const id = Number(row.id);
		const claimedAt = nowIso();
		await this.execute(
			`UPDATE messages SET status = 'claimed', claimed_by = ${toSqlValue(request.workerId)}, claimed_at = ${toSqlValue(claimedAt)}, lease_expires_at = ${toSqlValue(new Date(Date.now() + request.leaseSeconds * 1000).toISOString())}, attempts = attempts + 1, updated_at = ${toSqlValue(claimedAt)} WHERE id = ${id} AND status IN ('pending', 'failed')`,
		);
		return this.getById(id);
	}

	async ack(request: SdkAckMessageRequest) {
		await this.execute(`UPDATE messages SET status = ${toSqlValue(request.status)}, updated_at = ${toSqlValue(nowIso())} WHERE id = ${request.id}`);
	}

	async create(request: SdkCreateMessageRequest) {
		const timestamp = nowIso();
		await this.execute(
			`INSERT INTO messages (type, status, payload_json, related_model, related_id, priority, available_at, attempts, max_attempts, created_at, updated_at) VALUES (${toSqlValue(request.type)}, 'pending', ${toSqlValue(JSON.stringify(request.payload))}, ${toSqlValue(request.relatedModel ?? null)}, ${toSqlValue(request.relatedId ?? null)}, ${request.priority ?? 0}, ${toSqlValue(timestamp)}, 0, ${request.maxAttempts ?? 3}, ${toSqlValue(timestamp)}, ${toSqlValue(timestamp)})`,
		);
		const row = await this.selectFirst('SELECT * FROM messages ORDER BY id DESC LIMIT 1');
		if (!row) {
			throw new Error('Failed to create message record.');
		}
		return messageFromRow(row);
	}
}
