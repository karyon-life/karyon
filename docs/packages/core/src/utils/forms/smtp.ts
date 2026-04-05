import type { FormRuntimeCapabilities } from '../../types/forms';

interface EmailMessage {
	to: string[];
	subject: string;
	text: string;
	replyTo?: string;
}

export async function sendEmail(message: EmailMessage, runtime: FormRuntimeCapabilities) {
	if (runtime.isCloudflareRuntime) {
		const { sendEmailWithCloudflareSockets } = await import('./smtp-cloudflare');
		return sendEmailWithCloudflareSockets(message);
	}

	throw new Error('Email delivery requires Cloudflare runtime bindings in this docs deployment.');
}
