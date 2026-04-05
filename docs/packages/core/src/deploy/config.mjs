import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { parse as parseYaml } from 'yaml';
import { resolveTreeseedTenantRoot } from '../tenant/config.mjs';

const FORMS_MODES = new Set(['store_only', 'notify_admin', 'full_email']);
const AGENT_MODES = new Set(['stub', 'manual', 'copilot']);

function expectString(value, label) {
	if (typeof value !== 'string' || !value.trim()) {
		throw new Error(`Invalid deploy config: expected ${label} to be a non-empty string.`);
	}

	return value.trim();
}

function optionalString(value) {
	if (typeof value !== 'string' || !value.trim()) {
		return undefined;
	}

	return value.trim();
}

function optionalBoolean(value, label) {
	if (value === undefined) {
		return undefined;
	}

	if (typeof value !== 'boolean') {
		throw new Error(`Invalid deploy config: expected ${label} to be a boolean when provided.`);
	}

	return value;
}

function optionalFormsMode(value) {
	if (value === undefined) {
		return 'store_only';
	}

	const normalized = expectString(value, 'forms.mode');
	if (!FORMS_MODES.has(normalized)) {
		throw new Error(`Invalid deploy config: unsupported forms.mode "${normalized}".`);
	}

	return normalized;
}

function optionalAgentMode(value) {
	if (value === undefined) {
		return 'stub';
	}

	const normalized = expectString(value, 'agents.mode');
	if (!AGENT_MODES.has(normalized)) {
		throw new Error(`Invalid deploy config: unsupported agents.mode "${normalized}".`);
	}

	return normalized;
}

function parseDeployConfig(raw) {
	const parsed = parseYaml(raw) ?? {};
	const cloudflare = parsed.cloudflare ?? {};
	const forms = parsed.forms ?? {};
	const agents = parsed.agents ?? {};
	const smtp = parsed.smtp ?? {};
	const turnstile = parsed.turnstile ?? {};

	return {
		name: expectString(parsed.name, 'name'),
		slug: expectString(parsed.slug, 'slug'),
		siteUrl: expectString(parsed.siteUrl, 'siteUrl'),
		contactEmail: expectString(parsed.contactEmail, 'contactEmail'),
		cloudflare: {
			accountId: optionalString(cloudflare.accountId) ?? optionalString(process.env.CLOUDFLARE_ACCOUNT_ID) ?? 'replace-with-cloudflare-account-id',
			workerName: optionalString(cloudflare.workerName),
		},
		forms: {
			mode: optionalFormsMode(forms.mode),
		},
		agents: {
			mode: optionalAgentMode(agents.mode),
		},
		smtp: {
			enabled: optionalBoolean(smtp.enabled, 'smtp.enabled'),
		},
		turnstile: {
			enabled: optionalBoolean(turnstile.enabled, 'turnstile.enabled'),
		},
	};
}

export function resolveTreeseedDeployConfigPath(configPath = 'treeseed.site.yaml') {
	const tenantRoot = resolveTreeseedTenantRoot();
	const candidate = resolve(tenantRoot, configPath);
	if (!existsSync(candidate)) {
		throw new Error(`Unable to resolve Treeseed deploy config at "${candidate}".`);
	}
	return candidate;
}

export function deriveCloudflareWorkerName(config) {
	return config.cloudflare.workerName?.trim() || config.slug;
}

export function loadTreeseedDeployConfig(configPath = 'treeseed.site.yaml') {
	const resolvedConfigPath = resolveTreeseedDeployConfigPath(configPath);
	const tenantRoot = dirname(resolvedConfigPath);
	const parsed = parseDeployConfig(readFileSync(resolvedConfigPath, 'utf8'));

	Object.defineProperty(parsed, '__tenantRoot', {
		value: tenantRoot,
		enumerable: false,
	});

	Object.defineProperty(parsed, '__configPath', {
		value: resolvedConfigPath,
		enumerable: false,
	});

	return parsed;
}
