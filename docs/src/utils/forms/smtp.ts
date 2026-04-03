import type { FormRuntimeCapabilities } from '../../types/forms';

interface EmailMessage {
	to: string[];
	subject: string;
	text: string;
	replyTo?: string;
}

export async function sendEmail(message: EmailMessage, runtime: FormRuntimeCapabilities) {
	const shouldUseCloudflareTransport =
		runtime.isCloudflareRuntime && runtime.localDevMode !== 'astro';

	if (shouldUseCloudflareTransport) {
		const { sendEmailWithCloudflareSockets } = await import('./smtp-cloudflare');
		return sendEmailWithCloudflareSockets(message);
	}

	const { sendEmailWithNode } = await import('./smtp-node');
	return sendEmailWithNode(message);
}
