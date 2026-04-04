import type { SdkCursorRequest } from '../sdk-types';
import { SqliteStoreBase, nowIso, toSqlValue } from './helpers.ts';

export class CursorStore extends SqliteStoreBase {
	async upsert(request: SdkCursorRequest) {
		await this.execute(
			`INSERT OR REPLACE INTO agent_cursors (agent_slug, cursor_key, cursor_value, updated_at) VALUES (${toSqlValue(request.agentSlug)}, ${toSqlValue(request.cursorKey)}, ${toSqlValue(request.cursorValue)}, ${toSqlValue(nowIso())})`,
		);
	}
}
