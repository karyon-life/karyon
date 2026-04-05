import type {
	CloudflareRuntime,
	D1DatabaseLike,
	KvNamespaceLike,
} from '@treeseed/core/types/cloudflare';

declare global {
	interface Env {
		FORM_GUARD_KV: KvNamespaceLike;
		SUBSCRIBERS_DB: D1DatabaseLike;
		SESSION: KvNamespaceLike;
	}
}

declare namespace App {
	interface Locals {
		runtime: CloudflareRuntime;
	}
}

export {};
