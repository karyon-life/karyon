import type { CloudflareRuntime } from './types/cloudflare';

declare global {
	interface Env {
		FORM_GUARD_KV: import('./types/cloudflare').KvNamespaceLike;
		SUBSCRIBERS_DB: import('./types/cloudflare').D1DatabaseLike;
		SESSION: import('./types/cloudflare').KvNamespaceLike;
	}
}

declare namespace App {
	interface Locals {
		runtime: CloudflareRuntime;
	}
}

export {};
