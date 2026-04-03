import type { FormRuntimeCapabilities, LocalDevMode } from '../../types/forms';

interface RuntimeInputs {
	isCloudflareRuntime: boolean;
	localDevMode: LocalDevMode | null;
	isDevServer: boolean;
	bypassTurnstile: boolean | undefined;
	bypassCloudflareGuards: boolean | undefined;
	useMailpit: boolean;
}

export function deriveFormRuntimeCapabilities(input: RuntimeInputs): FormRuntimeCapabilities {
	const isLocalMode = input.isDevServer || Boolean(input.localDevMode);

	return {
		isCloudflareRuntime: input.isCloudflareRuntime,
		isLocalMode,
		localDevMode: input.localDevMode ?? 'production',
		bypassTurnstile: isLocalMode
			? (input.bypassTurnstile ?? input.localDevMode === 'astro')
			: false,
		bypassCloudflareGuards: isLocalMode
			? (input.bypassCloudflareGuards ?? input.localDevMode === 'astro')
			: false,
		useMailpit: isLocalMode ? input.useMailpit || input.localDevMode === 'astro' : false,
	};
}
