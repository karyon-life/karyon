import { getFormSecret } from './config';
import { createOpaqueId, signFormToken, verifyFormToken } from './crypto';
import { FORM_SESSION_COOKIE } from './constants';
import type { FormSubmitPayload } from '../../types/forms';

export async function issueFormToken(formType: FormSubmitPayload['formType']) {
	const sessionId = createOpaqueId();
	const nonce = createOpaqueId();
	const issuedAt = Date.now();
	const secret = getFormSecret();

	if (!secret) {
		throw new Error('DOCS_FORM_TOKEN_SECRET is not configured.');
	}

	const formToken = await signFormToken(
		{
			formType,
			sessionId,
			nonce,
			issuedAt,
		},
		secret,
	);

	return {
		formToken,
		sessionId,
		issuedAt,
		nonce,
	};
}

export async function verifyIssuedToken(formToken: string, sessionId: string, formType: FormSubmitPayload['formType']) {
	const secret = getFormSecret();

	if (!secret) {
		return { ok: false as const, reason: 'missing-secret' };
	}

	const result = await verifyFormToken(formToken, secret);

	if (!result.ok) {
		return result;
	}

	if (result.payload.sessionId !== sessionId || result.payload.formType !== formType) {
		return { ok: false as const, reason: 'mismatch', payload: result.payload };
	}

	return result;
}

export function createSessionCookie(sessionId: string, requestUrl?: URL) {
	const isSecureRequest = requestUrl?.protocol === 'https:';

	return {
		name: FORM_SESSION_COOKIE,
		value: sessionId,
		options: {
			httpOnly: true,
			path: '/',
			sameSite: 'lax' as const,
			secure: isSecureRequest,
			maxAge: 60 * 60,
		},
	};
}
