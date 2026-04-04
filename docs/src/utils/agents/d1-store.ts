import crypto from 'node:crypto';
import type {
	ContentLeaseRecord,
} from '../../types/agents';
import type { D1DatabaseLike } from '../../types/cloudflare';
import { applyFilters, applySort } from './sdk-filters.ts';
import type {
	SdkAckMessageRequest,
	SdkClaimMessageRequest,
	SdkCreateMessageRequest,
	SdkCursorRequest,
	SdkFilterCondition,
	SdkFollowRequest,
	SdkGetRequest,
	SdkLeaseReleaseRequest,
	SdkMessageEntity,
	SdkMutationRequest,
	SdkPickRequest,
	SdkPickResult,
	SdkRecordRunRequest,
	SdkRunEntity,
	SdkSearchRequest,
	SdkSubscriptionEntity,
} from './sdk-types';

export interface TryClaimContentLeaseInput {
	model: string;
	itemKey: string;
	claimedBy: string;
	leaseSeconds: number;
}

export interface AgentDatabase {
	get(request: SdkGetRequest): Promise<Record<string, unknown> | null>;
	search(request: SdkSearchRequest): Promise<Record<string, unknown>[]>;
	follow(request: SdkFollowRequest): Promise<{ items: Record<string, unknown>[]; since: string }>;
	pick(request: SdkPickRequest): Promise<SdkPickResult<Record<string, unknown>>>;
	create(request: SdkMutationRequest): Promise<Record<string, unknown>>;
	claimMessage(request: SdkClaimMessageRequest): Promise<SdkMessageEntity | null>;
	ackMessage(request: SdkAckMessageRequest): Promise<void>;
	createMessage(request: SdkCreateMessageRequest): Promise<SdkMessageEntity>;
	recordRun(request: SdkRecordRunRequest): Promise<SdkRunEntity>;
	upsertCursor(request: SdkCursorRequest): Promise<void>;
	releaseLease(request: SdkLeaseReleaseRequest): Promise<void>;
	tryClaimContentLease(input: TryClaimContentLeaseInput): Promise<string | null>;
	releaseAllLeases(): Promise<number>;
}

type DatabaseRow = Record<string, unknown>;

const D1_MODEL_TABLES: Record<'subscription' | 'message', string> = {
	subscription: 'subscriptions',
	message: 'messages',
};

function nowIso() {
	return new Date().toISOString();
}

function nextLeaseToken() {
	return crypto.randomUUID();
}

function toSqlValue(value: unknown) {
	if (value === null || value === undefined) {
		return 'NULL';
	}
	if (typeof value === 'number') {
		return String(value);
	}
	if (typeof value === 'boolean') {
		return value ? '1' : '0';
	}
	return `'${String(value).replace(/'/g, "''")}'`;
}

function messageFromRow(row: DatabaseRow): SdkMessageEntity {
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
		leaseExpiresAt: row.lease_expires_at
			? String(row.lease_expires_at)
			: row.leaseExpiresAt
				? String(row.leaseExpiresAt)
				: null,
		attempts: Number(row.attempts ?? 0),
		maxAttempts: Number(row.max_attempts ?? row.maxAttempts ?? 3),
		createdAt: String(row.created_at ?? row.createdAt ?? nowIso()),
		updatedAt: String(row.updated_at ?? row.updatedAt ?? nowIso()),
	};
}

function runFromRecord(row: Record<string, unknown>): SdkRunEntity {
	return {
		runId: String(row.runId ?? row.run_id ?? ''),
		agentSlug: String(row.agentSlug ?? row.agent_slug ?? ''),
		triggerSource: String(row.triggerSource ?? row.trigger_source ?? ''),
		status: String(row.status ?? ''),
		selectedItemKey:
			row.selectedItemKey !== undefined && row.selectedItemKey !== null
				? String(row.selectedItemKey)
				: row.selected_item_key !== undefined && row.selected_item_key !== null
					? String(row.selected_item_key)
					: null,
		selectedMessageId:
			row.selectedMessageId !== undefined && row.selectedMessageId !== null
				? Number(row.selectedMessageId)
				: row.selected_message_id !== undefined && row.selected_message_id !== null
					? Number(row.selected_message_id)
					: null,
		branchName:
			row.branchName !== undefined && row.branchName !== null
				? String(row.branchName)
				: row.branch_name !== undefined && row.branch_name !== null
					? String(row.branch_name)
					: null,
		prUrl:
			row.prUrl !== undefined && row.prUrl !== null
				? String(row.prUrl)
				: row.pr_url !== undefined && row.pr_url !== null
					? String(row.pr_url)
					: null,
		summary: row.summary !== undefined && row.summary !== null ? String(row.summary) : null,
		error: row.error !== undefined && row.error !== null ? String(row.error) : null,
		startedAt: String(row.startedAt ?? row.started_at ?? nowIso()),
		finishedAt:
			row.finishedAt !== undefined && row.finishedAt !== null
				? String(row.finishedAt)
				: row.finished_at !== undefined && row.finished_at !== null
					? String(row.finished_at)
					: null,
	};
}

function normalizeRow(model: string, row: DatabaseRow) {
	if (model === 'message') {
		return messageFromRow(row);
	}
	return row;
}

function buildFilterSql(filters: SdkFilterCondition[] = []) {
	const clauses = filters.map((filter) => {
		const field = filter.field;
		switch (filter.op) {
			case 'eq':
				return `${field} = ${toSqlValue(filter.value)}`;
			case 'in':
				return `${field} IN (${(Array.isArray(filter.value) ? filter.value : [filter.value]).map(toSqlValue).join(', ')})`;
			case 'contains':
				return `${field} LIKE ${toSqlValue(`%${String(filter.value ?? '')}%`)}`;
			case 'prefix':
				return `${field} LIKE ${toSqlValue(`${String(filter.value ?? '')}%`)}`;
			case 'gt':
				return `${field} > ${toSqlValue(filter.value)}`;
			case 'gte':
				return `${field} >= ${toSqlValue(filter.value)}`;
			case 'lt':
				return `${field} < ${toSqlValue(filter.value)}`;
			case 'lte':
				return `${field} <= ${toSqlValue(filter.value)}`;
			case 'updated_since':
				return `${field} >= ${toSqlValue(filter.value)}`;
			case 'related_to':
				return `${field} LIKE ${toSqlValue(`%${String(filter.value ?? '')}%`)}`;
			default:
				return '1 = 1';
		}
	});

	return clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
}

function buildOrderSql(sort: SdkSearchRequest['sort'] = []) {
	if (!sort || sort.length === 0) {
		return '';
	}
	return `ORDER BY ${sort
		.map((entry) => `${entry.field} ${entry.direction === 'asc' ? 'ASC' : 'DESC'}`)
		.join(', ')}`;
}

export class MemoryAgentDatabase implements AgentDatabase {
	private readonly subscriptions = new Map<string, SdkSubscriptionEntity>();
	private readonly messages = new Map<number, SdkMessageEntity>();
	private readonly runs = new Map<string, SdkRunEntity>();
	private readonly contentLeases = new Map<string, ContentLeaseRecord>();
	private readonly cursors = new Map<string, string>();
	private messageId = 0;

	constructor(seed?: {
		subscriptions?: SdkSubscriptionEntity[];
		messages?: SdkMessageEntity[];
	}) {
		for (const item of seed?.subscriptions ?? []) {
			this.subscriptions.set(String(item.id ?? item.email), item);
		}
		for (const message of seed?.messages ?? []) {
			this.messages.set(message.id, message);
			this.messageId = Math.max(this.messageId, message.id);
		}
	}

	private rowsForModel(model: string) {
		if (model === 'subscription') {
			return [...this.subscriptions.values()];
		}
		if (model === 'message') {
			return [...this.messages.values()];
		}
		throw new Error(`Unsupported D1 model "${model}".`);
	}

	async get(request: SdkGetRequest) {
		const rows = this.rowsForModel(request.model);
		return (
			rows.find((row) => {
				const key = String(request.id ?? request.slug ?? request.key ?? '');
				return [row.id, row.email].map((value) => String(value ?? '')).includes(key);
			}) ?? null
		) as Record<string, unknown> | null;
	}

	async search(request: SdkSearchRequest) {
		const filtered = applyFilters(this.rowsForModel(request.model) as Record<string, unknown>[], request.filters);
		const sorted = applySort(filtered as Record<string, unknown>[], request.sort);
		return sorted.slice(0, request.limit ?? sorted.length) as Record<string, unknown>[];
	}

	async follow(request: SdkFollowRequest) {
		const filters: SdkFilterCondition[] = [
			...(request.filters ?? []),
			{
				field: request.model === 'message' ? 'updatedAt' : 'updated_at',
				op: 'updated_since',
				value: request.since,
			},
		];

		return {
			items: await this.search({
				model: request.model,
				filters,
			}),
			since: request.since,
		};
	}

	async pick(request: SdkPickRequest): Promise<SdkPickResult<Record<string, unknown>>> {
		if (request.model === 'message') {
			const item = await this.claimMessage({
				workerId: request.workerId,
				messageTypes: request.filters
					?.filter((filter) => filter.field === 'type' && filter.op === 'in')
					.flatMap((filter) => (Array.isArray(filter.value) ? filter.value.map(String) : [])),
				leaseSeconds: request.leaseSeconds,
			});
			return {
				item: item as Record<string, unknown> | null,
				leaseToken: item ? nextLeaseToken() : null,
			};
		}

		const items = await this.search({
			model: request.model,
			filters: request.filters,
			sort: [{ field: 'updated_at', direction: 'desc' }],
		});
		return {
			item: items[0] ?? null,
			leaseToken: null,
		};
	}

	async create(request: SdkMutationRequest) {
		if (request.model !== 'message') {
			throw new Error(`D1 create is only implemented for the message model in v1.`);
		}
		return (await this.createMessage({
			type: String(request.data.type ?? 'message.created'),
			payload: (request.data.payload as Record<string, unknown> | undefined) ?? request.data,
			relatedModel: typeof request.data.relatedModel === 'string' ? request.data.relatedModel : null,
			relatedId: typeof request.data.relatedId === 'string' ? request.data.relatedId : null,
			priority: Number(request.data.priority ?? 0),
			maxAttempts: Number(request.data.maxAttempts ?? 3),
			actor: request.actor,
		})) as Record<string, unknown>;
	}

	async claimMessage(request: SdkClaimMessageRequest) {
		const pending = [...this.messages.values()]
			.filter((message) =>
				(message.status === 'pending' || message.status === 'failed')
				&& new Date(message.availableAt).valueOf() <= Date.now()
				&& (!request.messageTypes?.length || request.messageTypes.includes(message.type)),
			)
			.sort((left, right) => right.priority - left.priority || left.availableAt.localeCompare(right.availableAt))[0];

		if (!pending) {
			return null;
		}

		const claimedAt = nowIso();
		const next: SdkMessageEntity = {
			...pending,
			status: 'claimed',
			claimedBy: request.workerId,
			claimedAt,
			leaseExpiresAt: new Date(Date.now() + request.leaseSeconds * 1000).toISOString(),
			attempts: pending.attempts + 1,
			updatedAt: claimedAt,
		};
		this.messages.set(next.id, next);
		return next;
	}

	async ackMessage(request: SdkAckMessageRequest) {
		const current = this.messages.get(request.id);
		if (!current) {
			return;
		}
		this.messages.set(request.id, {
			...current,
			status: request.status,
			updatedAt: nowIso(),
		});
	}

	async createMessage(request: SdkCreateMessageRequest) {
		this.messageId += 1;
		const record: SdkMessageEntity = {
			id: this.messageId,
			type: request.type,
			status: 'pending',
			payloadJson: JSON.stringify(request.payload),
			relatedModel: request.relatedModel ?? null,
			relatedId: request.relatedId ?? null,
			priority: request.priority ?? 0,
			availableAt: nowIso(),
			claimedBy: null,
			claimedAt: null,
			leaseExpiresAt: null,
			attempts: 0,
			maxAttempts: request.maxAttempts ?? 3,
			createdAt: nowIso(),
			updatedAt: nowIso(),
		};
		this.messages.set(record.id, record);
		return record;
	}

	async recordRun(request: SdkRecordRunRequest) {
		const run = runFromRecord(request.run);
		this.runs.set(run.runId, run);
		return run;
	}

	async upsertCursor(request: SdkCursorRequest) {
		this.cursors.set(`${request.agentSlug}:${request.cursorKey}`, request.cursorValue);
	}

	async releaseLease(request: SdkLeaseReleaseRequest) {
		this.contentLeases.delete(`${request.model}:${request.itemKey}`);
	}

	async tryClaimContentLease(input: TryClaimContentLeaseInput) {
		const key = `${input.model}:${input.itemKey}`;
		const existing = this.contentLeases.get(key);
		if (existing && new Date(existing.leaseExpiresAt).valueOf() > Date.now()) {
			return null;
		}

		const token = nextLeaseToken();
		this.contentLeases.set(key, {
			model: input.model,
			itemKey: input.itemKey,
			claimedBy: input.claimedBy,
			claimedAt: nowIso(),
			leaseExpiresAt: new Date(Date.now() + input.leaseSeconds * 1000).toISOString(),
			token,
		});
		return token;
	}

	async releaseAllLeases() {
		const count = this.contentLeases.size;
		this.contentLeases.clear();
		return count;
	}
}

export class CloudflareD1AgentDatabase implements AgentDatabase {
	constructor(readonly db: D1DatabaseLike) {}

	private async selectAll(query: string) {
		const result = await this.db.prepare(query).all<DatabaseRow>();
		return result.results ?? [];
	}

	private async selectFirst(query: string) {
		return this.db.prepare(query).first<DatabaseRow>();
	}

	private async execute(query: string) {
		await this.db.prepare(query).run();
	}

	async get(request: SdkGetRequest) {
		const model = request.model === 'subscription' || request.model === 'message' ? request.model : null;
		if (!model) {
			throw new Error(`Unsupported D1 get model "${request.model}".`);
		}
		const table = D1_MODEL_TABLES[model];
		const key = request.id ?? request.slug ?? request.key ?? '';
		const field = model === 'subscription' && String(key).includes('@') ? 'email' : 'id';
		const row = await this.selectFirst(`SELECT * FROM ${table} WHERE ${field} = ${toSqlValue(key)} LIMIT 1`);
		return row ? (normalizeRow(model, row) as Record<string, unknown>) : null;
	}

	async search(request: SdkSearchRequest) {
		const model = request.model === 'subscription' || request.model === 'message' ? request.model : null;
		if (!model) {
			throw new Error(`Unsupported D1 search model "${request.model}".`);
		}
		const table = D1_MODEL_TABLES[model];
		const sql = [
			`SELECT * FROM ${table}`,
			buildFilterSql(request.filters),
			buildOrderSql(request.sort),
			request.limit ? `LIMIT ${request.limit}` : '',
		]
			.filter(Boolean)
			.join(' ');
		const rows = await this.selectAll(sql);
		return rows.map((row) => normalizeRow(model, row) as Record<string, unknown>);
	}

	async follow(request: SdkFollowRequest) {
		const field = request.model === 'message' ? 'updated_at' : 'updated_at';
		return this.search({
			model: request.model,
			filters: [
				...(request.filters ?? []),
				{
					field,
					op: 'updated_since',
					value: request.since,
				},
			],
		}).then((items) => ({ items, since: request.since }));
	}

	async pick(request: SdkPickRequest) {
		if (request.model === 'message') {
			const claimed = await this.claimMessage({
				workerId: request.workerId,
				messageTypes: request.filters
					?.filter((filter) => filter.field === 'type' && filter.op === 'in')
					.flatMap((filter) => (Array.isArray(filter.value) ? filter.value.map(String) : [])),
				leaseSeconds: request.leaseSeconds,
			});
			return {
				item: claimed as Record<string, unknown> | null,
				leaseToken: claimed ? nextLeaseToken() : null,
			};
		}

		return {
			item: null,
			leaseToken: null,
		};
	}

	async create(request: SdkMutationRequest) {
		if (request.model !== 'message') {
			throw new Error(`D1 create is only implemented for message records.`);
		}
		return (await this.createMessage({
			type: String(request.data.type ?? 'message.created'),
			payload: (request.data.payload as Record<string, unknown> | undefined) ?? request.data,
			relatedModel: typeof request.data.relatedModel === 'string' ? request.data.relatedModel : null,
			relatedId: typeof request.data.relatedId === 'string' ? request.data.relatedId : null,
			priority: Number(request.data.priority ?? 0),
			maxAttempts: Number(request.data.maxAttempts ?? 3),
			actor: request.actor,
		})) as Record<string, unknown>;
	}

	async claimMessage(request: SdkClaimMessageRequest) {
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
		const claimed = await this.selectFirst(`SELECT * FROM messages WHERE id = ${id} LIMIT 1`);
		return claimed ? messageFromRow(claimed) : null;
	}

	async ackMessage(request: SdkAckMessageRequest) {
		await this.execute(
			`UPDATE messages SET status = ${toSqlValue(request.status)}, updated_at = ${toSqlValue(nowIso())} WHERE id = ${request.id}`,
		);
	}

	async createMessage(request: SdkCreateMessageRequest) {
		const timestamp = nowIso();
		await this.execute(
			`INSERT INTO messages (type, status, payload_json, related_model, related_id, priority, available_at, attempts, max_attempts, created_at, updated_at) VALUES (${toSqlValue(request.type)}, 'pending', ${toSqlValue(JSON.stringify(request.payload))}, ${toSqlValue(request.relatedModel ?? null)}, ${toSqlValue(request.relatedId ?? null)}, ${request.priority ?? 0}, ${toSqlValue(timestamp)}, 0, ${request.maxAttempts ?? 3}, ${toSqlValue(timestamp)}, ${toSqlValue(timestamp)})`,
		);
		const created = await this.selectFirst('SELECT * FROM messages ORDER BY id DESC LIMIT 1');
		if (!created) {
			throw new Error('Failed to create message record.');
		}
		return messageFromRow(created);
	}

	async recordRun(request: SdkRecordRunRequest) {
		const run = runFromRecord(request.run);
		await this.execute(
			`INSERT OR REPLACE INTO agent_runs (run_id, agent_slug, trigger_source, status, selected_item_key, selected_message_id, branch_name, pr_url, summary, error, started_at, finished_at) VALUES (${toSqlValue(run.runId)}, ${toSqlValue(run.agentSlug)}, ${toSqlValue(run.triggerSource)}, ${toSqlValue(run.status)}, ${toSqlValue(run.selectedItemKey)}, ${toSqlValue(run.selectedMessageId)}, ${toSqlValue(run.branchName)}, ${toSqlValue(run.prUrl)}, ${toSqlValue(run.summary)}, ${toSqlValue(run.error)}, ${toSqlValue(run.startedAt)}, ${toSqlValue(run.finishedAt)})`,
		);
		return run;
	}

	async upsertCursor(request: SdkCursorRequest) {
		await this.execute(
			`INSERT OR REPLACE INTO agent_cursors (agent_slug, cursor_key, cursor_value, updated_at) VALUES (${toSqlValue(request.agentSlug)}, ${toSqlValue(request.cursorKey)}, ${toSqlValue(request.cursorValue)}, ${toSqlValue(nowIso())})`,
		);
	}

	async releaseLease(request: SdkLeaseReleaseRequest) {
		await this.execute(
			`DELETE FROM content_leases WHERE model = ${toSqlValue(request.model)} AND item_key = ${toSqlValue(request.itemKey)}`,
		);
	}

	async tryClaimContentLease(input: TryClaimContentLeaseInput) {
		const existing = await this.selectFirst(
			`SELECT * FROM content_leases WHERE model = ${toSqlValue(input.model)} AND item_key = ${toSqlValue(input.itemKey)} LIMIT 1`,
		);
		if (existing && new Date(String(existing.lease_expires_at ?? 0)).valueOf() > Date.now()) {
			return null;
		}

		const token = nextLeaseToken();
		await this.execute(
			`INSERT OR REPLACE INTO content_leases (model, item_key, claimed_by, claimed_at, lease_expires_at, token) VALUES (${toSqlValue(input.model)}, ${toSqlValue(input.itemKey)}, ${toSqlValue(input.claimedBy)}, ${toSqlValue(nowIso())}, ${toSqlValue(new Date(Date.now() + input.leaseSeconds * 1000).toISOString())}, ${toSqlValue(token)})`,
		);
		return token;
	}

	async releaseAllLeases() {
		const rows = await this.selectAll('SELECT COUNT(*) AS count FROM content_leases');
		await this.execute('DELETE FROM content_leases');
		return Number(rows[0]?.count ?? 0);
	}
}
