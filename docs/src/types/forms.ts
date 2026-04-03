export const CONTACT_TYPES = ['question', 'feedback', 'collaboration', 'issue'] as const;

export type ContactType = (typeof CONTACT_TYPES)[number];

export interface ContactSubmission {
	formType: 'contact';
	name: string;
	email: string;
	organization: string;
	contactType: ContactType;
	subject: string;
	message: string;
}

export interface SubscribeSubmission {
	formType: 'subscribe';
	email: string;
	name: string;
}

export type FormSubmitPayload = ContactSubmission | SubscribeSubmission;

export interface SignedFormTokenPayload {
	formType: FormSubmitPayload['formType'];
	sessionId: string;
	nonce: string;
	issuedAt: number;
}

export type ContactRoutingMap = Partial<Record<ContactType | 'default', string[]>>;

export type LocalDevMode = 'astro' | 'cloudflare';

export interface SubscriberRecordInput {
	email: string;
	name: string;
	source: string;
	ip: string;
}

export interface GuardStore {
	assertNonceUnused(nonce: string): Promise<boolean>;
	applyRateLimit(remoteIp: string, email: string, formType: string): Promise<boolean>;
}

export interface SubscriberStore {
	upsert(input: SubscriberRecordInput): Promise<void>;
}

export interface FormRuntimeCapabilities {
	isCloudflareRuntime: boolean;
	isLocalMode: boolean;
	localDevMode: LocalDevMode | 'production';
	bypassTurnstile: boolean;
	bypassCloudflareGuards: boolean;
	useMailpit: boolean;
}

export interface SubmitResult {
	ok: boolean;
	code:
		| 'success'
		| 'invalid_request'
		| 'invalid_form'
		| 'captcha_failed'
		| 'token_invalid'
		| 'token_expired'
		| 'token_replayed'
		| 'rate_limited'
		| 'config_error'
		| 'delivery_failed';
		message: string;
		redirectTo: string;
}
