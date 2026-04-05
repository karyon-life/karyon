import type {
	SdkCursorEntity,
	SdkCursorRequest,
	SdkGetCursorRequest,
	SdkSearchRequest,
	SdkUpdateRequest,
} from '../sdk-types.ts';
import { SqliteStoreBase, nowIso, toSqlValue } from './helpers.ts';

function cursorFromRow(row: Record<string, unknown>): SdkCursorEntity {
	return {
		agentSlug: String(row.agentSlug ?? row.agent_slug ?? ''),
		cursorKey: String(row.cursorKey ?? row.cursor_key ?? ''),
		cursorValue: String(row.cursorValue ?? row.cursor_value ?? ''),
		updatedAt:
			row.updatedAt !== undefined && row.updatedAt !== null
				? String(row.updatedAt)
				: row.updated_at !== undefined && row.updated_at !== null
					? String(row.updated_at)
					: null,
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

export class CursorStore extends SqliteStoreBase {
	async getByKey(key: string) {
		const [agentSlug, cursorKey] = key.split(':', 2);
		if (!agentSlug || !cursorKey) {
			return null;
		}
		const row = await this.selectFirst(
			`SELECT * FROM agent_cursors WHERE agent_slug = ${toSqlValue(agentSlug)} AND cursor_key = ${toSqlValue(cursorKey)} LIMIT 1`,
		);
		return row ? cursorFromRow(row) : null;
	}

	async get(request: SdkGetCursorRequest) {
		const row = await this.selectFirst(
			`SELECT cursor_value FROM agent_cursors WHERE agent_slug = ${toSqlValue(request.agentSlug)} AND cursor_key = ${toSqlValue(request.cursorKey)} LIMIT 1`,
		);
		return row?.cursor_value !== undefined && row?.cursor_value !== null ? String(row.cursor_value) : null;
	}

	async search(request: SdkSearchRequest) {
		const sql = [
			'SELECT * FROM agent_cursors',
			buildFilterSql(request.filters),
			request.sort?.length
				? `ORDER BY ${request.sort.map((entry) => `${entry.field} ${entry.direction === 'asc' ? 'ASC' : 'DESC'}`).join(', ')}`
				: '',
			request.limit ? `LIMIT ${request.limit}` : '',
		].filter(Boolean).join(' ');
		const rows = await this.selectAll(sql);
		return rows.map(cursorFromRow);
	}

	async upsert(request: SdkCursorRequest) {
		await this.execute(
			`INSERT OR REPLACE INTO agent_cursors (agent_slug, cursor_key, cursor_value, updated_at) VALUES (${toSqlValue(request.agentSlug)}, ${toSqlValue(request.cursorKey)}, ${toSqlValue(request.cursorValue)}, ${toSqlValue(nowIso())})`,
		);
	}

	async update(request: SdkUpdateRequest) {
		const agentSlug = String(request.data.agentSlug ?? request.id ?? request.key ?? '');
		const cursorKey = String(request.data.cursorKey ?? request.slug ?? '');
		const cursorValue = String(request.data.cursorValue ?? '');
		await this.upsert({
			agentSlug,
			cursorKey,
			cursorValue,
		});
		return this.getByKey(`${agentSlug}:${cursorKey}`);
	}
}
