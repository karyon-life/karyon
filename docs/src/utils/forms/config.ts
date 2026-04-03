import {
	DOCS_CONTACT_ROUTING_JSON,
	DOCS_FORM_TOKEN_SECRET,
	DOCS_FORMS_LOCAL_BYPASS_CLOUDFLARE_GUARDS,
	DOCS_FORMS_LOCAL_BYPASS_TURNSTILE,
	DOCS_FORMS_LOCAL_USE_MAILPIT,
	DOCS_LOCAL_DEV_MODE,
	DOCS_MAILPIT_SMTP_HOST,
	DOCS_MAILPIT_SMTP_PORT,
	DOCS_SMTP_FROM,
	DOCS_SMTP_HOST,
	DOCS_SMTP_PASSWORD,
	DOCS_SMTP_PORT,
	DOCS_SMTP_REPLY_TO,
	DOCS_SMTP_USERNAME,
	DOCS_SUBSCRIBE_NOTIFY_RECIPIENTS,
	DOCS_TURNSTILE_SECRET_KEY,
} from 'astro:env/server';
import type { ContactRoutingMap, LocalDevMode } from '../../types/forms';

function parseEmailList(value: string | undefined) {
	return (value ?? '')
		.split(',')
		.map((entry) => entry.trim())
		.filter(Boolean);
}

function parseRoutingMap(value: string | undefined): ContactRoutingMap {
	if (!value) {
		return {};
	}

	try {
		const parsed = JSON.parse(value) as Record<string, unknown>;
		return Object.fromEntries(
			Object.entries(parsed).map(([key, rawValue]) => [
				key,
				Array.isArray(rawValue)
					? rawValue
							.map((entry) => (typeof entry === 'string' ? entry.trim() : ''))
							.filter(Boolean)
					: [],
			]),
		);
	} catch (error) {
		console.error('Failed to parse DOCS_CONTACT_ROUTING_JSON', error);
		return {};
	}
}

export function getFormSecret() {
	return DOCS_FORM_TOKEN_SECRET ?? '';
}

export function getTurnstileSecret() {
	return DOCS_TURNSTILE_SECRET_KEY ?? '';
}

export function getContactRoutingMap() {
	return parseRoutingMap(DOCS_CONTACT_ROUTING_JSON);
}

export function getSubscribeRecipients() {
	return parseEmailList(DOCS_SUBSCRIBE_NOTIFY_RECIPIENTS);
}

export function getSmtpConfig() {
	const useMailpit = DOCS_FORMS_LOCAL_USE_MAILPIT ?? false;
	return {
		host: useMailpit ? (DOCS_MAILPIT_SMTP_HOST ?? DOCS_SMTP_HOST ?? '127.0.0.1') : (DOCS_SMTP_HOST ?? ''),
		port: useMailpit ? (DOCS_MAILPIT_SMTP_PORT ?? DOCS_SMTP_PORT ?? 1025) : (DOCS_SMTP_PORT ?? 465),
		username: DOCS_SMTP_USERNAME ?? '',
		password: DOCS_SMTP_PASSWORD ?? '',
		from: DOCS_SMTP_FROM ?? '',
		replyTo: DOCS_SMTP_REPLY_TO ?? '',
	};
}

export function getLocalDevMode(): LocalDevMode | null {
	if (DOCS_LOCAL_DEV_MODE === 'cloudflare') {
		return 'cloudflare';
	}

	if (DOCS_LOCAL_DEV_MODE === 'astro') {
		return 'astro';
	}

	return null;
}

export function shouldBypassTurnstileByEnv() {
	return DOCS_FORMS_LOCAL_BYPASS_TURNSTILE;
}

export function shouldBypassCloudflareGuardsByEnv() {
	return DOCS_FORMS_LOCAL_BYPASS_CLOUDFLARE_GUARDS;
}

export function shouldUseMailpit() {
	return DOCS_FORMS_LOCAL_USE_MAILPIT ?? false;
}
