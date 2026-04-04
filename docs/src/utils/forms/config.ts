import {
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
	DOCS_TURNSTILE_SECRET_KEY,
} from 'astro:env/server';
import { SITE_EMAIL_NOTIFICATIONS } from '../site-config';
import type { ContactRoutingMap, LocalDevMode } from '../../types/forms';

export function getFormSecret() {
	return DOCS_FORM_TOKEN_SECRET ?? '';
}

export function getTurnstileSecret() {
	return DOCS_TURNSTILE_SECRET_KEY ?? '';
}

export function getContactRoutingMap() {
	return SITE_EMAIL_NOTIFICATIONS.contactRouting as ContactRoutingMap;
}

export function getSubscribeRecipients() {
	return SITE_EMAIL_NOTIFICATIONS.subscribeRecipients;
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
