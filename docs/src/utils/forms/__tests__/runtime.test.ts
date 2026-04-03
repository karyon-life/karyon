import { describe, expect, it } from 'vitest';
import { deriveFormRuntimeCapabilities } from '../runtime-core';

describe('form runtime capabilities', () => {
	it('defaults astro local mode to bypasses and MailPit', () => {
		const runtime = deriveFormRuntimeCapabilities({
			isCloudflareRuntime: false,
			localDevMode: 'astro',
			isDevServer: true,
			bypassTurnstile: undefined,
			bypassCloudflareGuards: undefined,
			useMailpit: false,
		});

		expect(runtime.isLocalMode).toBe(true);
		expect(runtime.bypassTurnstile).toBe(true);
		expect(runtime.bypassCloudflareGuards).toBe(true);
		expect(runtime.useMailpit).toBe(true);
	});

	it('keeps cloudflare local mode production-like unless bypass flags are set', () => {
		const runtime = deriveFormRuntimeCapabilities({
			isCloudflareRuntime: true,
			localDevMode: 'cloudflare',
			isDevServer: false,
			bypassTurnstile: false,
			bypassCloudflareGuards: false,
			useMailpit: true,
		});

		expect(runtime.isLocalMode).toBe(true);
		expect(runtime.bypassTurnstile).toBe(false);
		expect(runtime.bypassCloudflareGuards).toBe(false);
		expect(runtime.useMailpit).toBe(true);
	});

	it('disables all local behavior in production mode', () => {
		const runtime = deriveFormRuntimeCapabilities({
			isCloudflareRuntime: true,
			localDevMode: null,
			isDevServer: false,
			bypassTurnstile: true,
			bypassCloudflareGuards: true,
			useMailpit: true,
		});

		expect(runtime.isLocalMode).toBe(false);
		expect(runtime.localDevMode).toBe('production');
		expect(runtime.bypassTurnstile).toBe(false);
		expect(runtime.bypassCloudflareGuards).toBe(false);
	});
});
