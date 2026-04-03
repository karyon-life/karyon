export interface KvNamespacePutOptions {
	expirationTtl?: number;
}

export interface KvNamespaceLike {
	get(key: string): Promise<string | null>;
	put(key: string, value: string, options?: KvNamespacePutOptions): Promise<void>;
}

export interface D1PreparedStatementLike {
	bind(...values: unknown[]): D1PreparedStatementLike;
	run(): Promise<unknown>;
}

export interface D1DatabaseLike {
	prepare(query: string): D1PreparedStatementLike;
}

export interface CloudflareRuntime {
	env: {
		FORM_GUARD_KV: KvNamespaceLike;
		SUBSCRIBERS_DB: D1DatabaseLike;
		SESSION: KvNamespaceLike;
	};
}
