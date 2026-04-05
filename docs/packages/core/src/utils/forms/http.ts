import { FORM_CODE_PARAM, FORM_SUCCESS_PARAM, SUBSCRIBE_ANCHOR_ID } from './constants';

export function getRemoteIp(request: Request) {
	return request.headers.get('CF-Connecting-IP') ?? request.headers.get('X-Forwarded-For') ?? '';
}

export function buildRedirectTarget(formType: 'contact' | 'subscribe', rawRedirectTo: string, isSuccess: boolean, code: string) {
	const fallback = formType === 'contact' ? '/contact/' : '/';
	const url = new URL(rawRedirectTo || fallback, 'https://karyon.life');
	url.searchParams.set(FORM_SUCCESS_PARAM, isSuccess ? 'success' : 'error');
	url.searchParams.set(FORM_CODE_PARAM, code);

	if (formType === 'subscribe') {
		url.hash = SUBSCRIBE_ANCHOR_ID;
	}

	return `${url.pathname}${url.search}${url.hash}`;
}

export function sanitizeRedirectTo(rawRedirectTo: string | null, formType: 'contact' | 'subscribe') {
	if (!rawRedirectTo) {
		return formType === 'contact' ? '/contact/' : '/';
	}

	try {
		const url = new URL(rawRedirectTo, 'https://karyon.life');
		if (url.origin !== 'https://karyon.life') {
			return formType === 'contact' ? '/contact/' : '/';
		}
		return `${url.pathname}${url.search}${url.hash}`;
	} catch {
		return formType === 'contact' ? '/contact/' : '/';
	}
}
