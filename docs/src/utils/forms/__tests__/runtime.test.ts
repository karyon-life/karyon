import { describe, expect, it } from 'vitest';
import { deriveFormRuntimeCapabilities } from '../runtime-core';

describe('form runtime capabilities', () => {
	it('keeps Cloudflare local mode strict unless bypass flags are explicitly enabled', () => {
		const runtime = deriveFormRuntimeCapabilities({
			isCloudflareRuntime: true,
			localDevMode: 'cloudflare',
			isDevServer: false,
			bypassTurnstile: undefined,
			bypassCloudflareGuards: undefined,
			useMailpit: false,
		});

		expect(runtime.isLocalMode).toBe(true);
		expect(runtime.bypassTurnstile).toBe(false);
		expect(runtime.bypassCloudflareGuards).toBe(false);
		expect(runtime.useMailpit).toBe(false);
	});

	it('honors explicit local Cloudflare toggles', () => {
		const runtime = deriveFormRuntimeCapabilities({
			isCloudflareRuntime: true,
			localDevMode: 'cloudflare',
			isDevServer: false,
			bypassTurnstile: true,
			bypassCloudflareGuards: true,
			useMailpit: true,
		});

		expect(runtime.isLocalMode).toBe(true);
		expect(runtime.bypassTurnstile).toBe(true);
		expect(runtime.bypassCloudflareGuards).toBe(true);
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
