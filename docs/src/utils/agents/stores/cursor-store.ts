import type { SdkCursorRequest, SdkGetCursorRequest } from '../sdk-types';
import { SqliteStoreBase, nowIso, toSqlValue } from './helpers.ts';

export class CursorStore extends SqliteStoreBase {
	async get(request: SdkGetCursorRequest) {
		const row = await this.selectFirst(
			`SELECT cursor_value FROM agent_cursors WHERE agent_slug = ${toSqlValue(request.agentSlug)} AND cursor_key = ${toSqlValue(request.cursorKey)} LIMIT 1`,
		);
		return row?.cursor_value !== undefined && row?.cursor_value !== null ? String(row.cursor_value) : null;
	}

	async upsert(request: SdkCursorRequest) {
		await this.execute(
			`INSERT OR REPLACE INTO agent_cursors (agent_slug, cursor_key, cursor_value, updated_at) VALUES (${toSqlValue(request.agentSlug)}, ${toSqlValue(request.cursorKey)}, ${toSqlValue(request.cursorValue)}, ${toSqlValue(nowIso())})`,
		);
	}
}
