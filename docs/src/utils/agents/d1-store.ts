import crypto from 'node:crypto';
import type { ContentLeaseRecord } from '../../types/agents';
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
	SdkSearchRequest,
	SdkSubscriptionEntity,
} from './sdk-types';
import { CursorStore } from './stores/cursor-store.ts';
import { LeaseStore, type LeaseClaimInput } from './stores/lease-store.ts';
import { MessageStore } from './stores/message-store.ts';
import { RunStore } from './stores/run-store.ts';
import { SubscriptionStore } from './stores/subscription-store.ts';

export interface TryClaimContentLeaseInput extends LeaseClaimInput {}

export interface AgentDatabase {
	get(request: SdkGetRequest): Promise<Record<string, unknown> | null>;
	search(request: SdkSearchRequest): Promise<Record<string, unknown>[]>;
	follow(request: SdkFollowRequest): Promise<{ items: Record<string, unknown>[]; since: string }>;
	pick(request: SdkPickRequest): Promise<SdkPickResult<Record<string, unknown>>>;
	create(request: SdkMutationRequest): Promise<Record<string, unknown>>;
	claimMessage(request: SdkClaimMessageRequest): Promise<SdkMessageEntity | null>;
	ackMessage(request: SdkAckMessageRequest): Promise<void>;
	createMessage(request: SdkCreateMessageRequest): Promise<SdkMessageEntity>;
	recordRun(request: SdkRecordRunRequest): Promise<Record<string, unknown>>;
	upsertCursor(request: SdkCursorRequest): Promise<void>;
	releaseLease(request: SdkLeaseReleaseRequest): Promise<void>;
	tryClaimContentLease(input: TryClaimContentLeaseInput): Promise<string | null>;
	releaseAllLeases(): Promise<number>;
}

function nowIso() {
	return new Date().toISOString();
}

function nextLeaseToken() {
	return crypto.randomUUID();
}

export class MemoryAgentDatabase implements AgentDatabase {
	private readonly subscriptions = new Map<string, SdkSubscriptionEntity>();
	private readonly messages = new Map<number, SdkMessageEntity>();
	private readonly runs = new Map<string, Record<string, unknown>>();
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
		this.runs.set(String(request.run.runId), request.run);
		return request.run;
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

	inspectRuns() {
		return [...this.runs.values()];
	}

	inspectLeases() {
		return [...this.contentLeases.values()];
	}
}

export class CloudflareD1AgentDatabase implements AgentDatabase {
	private readonly subscriptions: SubscriptionStore;
	private readonly messages: MessageStore;
	private readonly runs: RunStore;
	private readonly cursors: CursorStore;
	private readonly leases: LeaseStore;

	constructor(readonly db: D1DatabaseLike) {
		this.subscriptions = new SubscriptionStore(db);
		this.messages = new MessageStore(db);
		this.runs = new RunStore(db);
		this.cursors = new CursorStore(db);
		this.leases = new LeaseStore(db);
	}

	async get(request: SdkGetRequest) {
		if (request.model === 'subscription') {
			return this.subscriptions.getByKey(String(request.id ?? request.slug ?? request.key ?? '')) as Promise<Record<string, unknown> | null>;
		}
		if (request.model === 'message') {
			return this.messages.getById(Number(request.id ?? request.slug ?? request.key ?? 0)) as Promise<Record<string, unknown> | null>;
		}
		throw new Error(`Unsupported D1 get model "${request.model}".`);
	}

	async search(request: SdkSearchRequest) {
		if (request.model === 'subscription') {
			return this.subscriptions.search(request) as Promise<Record<string, unknown>[]>;
		}
		if (request.model === 'message') {
			return this.messages.search(request) as Promise<Record<string, unknown>[]>;
		}
		throw new Error(`Unsupported D1 search model "${request.model}".`);
	}

	async follow(request: SdkFollowRequest) {
		return this.search({
			model: request.model,
			filters: [
				...(request.filters ?? []),
				{ field: 'updated_at', op: 'updated_since', value: request.since },
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

	claimMessage(request: SdkClaimMessageRequest) {
		return this.messages.claim(request);
	}

	ackMessage(request: SdkAckMessageRequest) {
		return this.messages.ack(request);
	}

	createMessage(request: SdkCreateMessageRequest) {
		return this.messages.create(request);
	}

	recordRun(request: SdkRecordRunRequest) {
		return this.runs.record(request);
	}

	upsertCursor(request: SdkCursorRequest) {
		return this.cursors.upsert(request);
	}

	releaseLease(request: SdkLeaseReleaseRequest) {
		return this.leases.release(request);
	}

	tryClaimContentLease(input: TryClaimContentLeaseInput) {
		return this.leases.tryClaim(input);
	}

	releaseAllLeases() {
		return this.leases.releaseAll();
	}
}
