import { createHash, randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { deriveCloudflareWorkerName, loadTreeseedDeployConfig } from '../src/deploy/config.mjs';
import { wranglerBin } from './package-tools.mjs';

const DEFAULT_COMPATIBILITY_DATE = '2026-04-05';
const DEFAULT_COMPATIBILITY_FLAGS = ['nodejs_compat'];
const GENERATED_ROOT = '.treeseed/generated';
const STATE_ROOT = '.treeseed/state';
const GENERATED_WRANGLER_PATH = `${GENERATED_ROOT}/wrangler.toml`;
const STATE_PATH = `${STATE_ROOT}/deploy.json`;

function ensureParent(filePath) {
	mkdirSync(dirname(filePath), { recursive: true });
}

function stableHash(value) {
	return createHash('sha256').update(value).digest('hex');
}

function readJson(filePath, fallback) {
	if (!existsSync(filePath)) {
		return fallback;
	}

	try {
		return JSON.parse(readFileSync(filePath, 'utf8'));
	} catch {
		return fallback;
	}
}

function writeJson(filePath, value) {
	ensureParent(filePath);
	writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function renderTomlString(value) {
	return JSON.stringify(String(value));
}

function envOrNull(key) {
	const value = process.env[key];
	return typeof value === 'string' && value.length ? value : null;
}

function relativeFromGeneratedRoot(targetPath) {
	return relative(resolve(process.cwd(), GENERATED_ROOT), targetPath).replaceAll('\\', '/');
}

function buildPublicVars(deployConfig) {
	return {
		DOCS_AGENT_EXECUTION_MODE: deployConfig.agents?.mode ?? 'stub',
		DOCS_PUBLIC_TURNSTILE_SITE_KEY: deployConfig.turnstile?.enabled ? (envOrNull('DOCS_PUBLIC_TURNSTILE_SITE_KEY') ?? '') : '',
	};
}

function buildSecretMap(deployConfig, state) {
	const generatedSecret = state.generatedSecrets?.DOCS_FORM_TOKEN_SECRET ?? randomBytes(24).toString('hex');
	return {
		DOCS_FORM_TOKEN_SECRET: envOrNull('DOCS_FORM_TOKEN_SECRET') ?? generatedSecret,
		DOCS_TURNSTILE_SECRET_KEY: deployConfig.turnstile?.enabled ? envOrNull('DOCS_TURNSTILE_SECRET_KEY') : null,
		DOCS_SMTP_HOST: deployConfig.smtp?.enabled ? envOrNull('DOCS_SMTP_HOST') : null,
		DOCS_SMTP_PORT: deployConfig.smtp?.enabled ? envOrNull('DOCS_SMTP_PORT') : null,
		DOCS_SMTP_USERNAME: deployConfig.smtp?.enabled ? envOrNull('DOCS_SMTP_USERNAME') : null,
		DOCS_SMTP_PASSWORD: deployConfig.smtp?.enabled ? envOrNull('DOCS_SMTP_PASSWORD') : null,
		DOCS_SMTP_FROM: deployConfig.smtp?.enabled ? envOrNull('DOCS_SMTP_FROM') : null,
		DOCS_SMTP_REPLY_TO: deployConfig.smtp?.enabled ? envOrNull('DOCS_SMTP_REPLY_TO') : null,
	};
}

function defaultStateFromConfig(deployConfig) {
	const workerName = deriveCloudflareWorkerName(deployConfig);
	return {
		workerName,
		kvNamespaces: {
			FORM_GUARD_KV: {
				name: `${workerName}-form-guard`,
				id: `dryrun-${deployConfig.slug}-form-guard`,
				previewId: `dryrun-${deployConfig.slug}-form-guard-preview`,
			},
			SESSION: {
				name: `${workerName}-session`,
				id: `dryrun-${deployConfig.slug}-session`,
				previewId: `dryrun-${deployConfig.slug}-session-preview`,
			},
		},
		d1Databases: {
			SUBSCRIBERS_DB: {
				databaseName: `${workerName}-subscribers`,
				databaseId: `dryrun-${deployConfig.slug}-subscribers`,
				previewDatabaseId: `dryrun-${deployConfig.slug}-subscribers-preview`,
			},
		},
		generatedSecrets: {},
		lastDeployedUrl: null,
		lastManifestFingerprint: null,
		lastDeploymentTimestamp: null,
	};
}

export function loadDeployState(tenantRoot, deployConfig) {
	const statePath = resolve(tenantRoot, STATE_PATH);
	const defaults = defaultStateFromConfig(deployConfig);
	const persisted = readJson(statePath, {});
	const merged = {
		...defaults,
		...persisted,
		kvNamespaces: {
			...defaults.kvNamespaces,
			...(persisted.kvNamespaces ?? {}),
			FORM_GUARD_KV: {
				...defaults.kvNamespaces.FORM_GUARD_KV,
				...(persisted.kvNamespaces?.FORM_GUARD_KV ?? {}),
			},
			SESSION: {
				...defaults.kvNamespaces.SESSION,
				...(persisted.kvNamespaces?.SESSION ?? {}),
			},
		},
		d1Databases: {
			...defaults.d1Databases,
			...(persisted.d1Databases ?? {}),
			SUBSCRIBERS_DB: {
				...defaults.d1Databases.SUBSCRIBERS_DB,
				...(persisted.d1Databases?.SUBSCRIBERS_DB ?? {}),
			},
		},
		generatedSecrets: {
			...(defaults.generatedSecrets ?? {}),
			...(persisted.generatedSecrets ?? {}),
		},
	};

	merged.workerName = defaults.workerName;
	merged.kvNamespaces.FORM_GUARD_KV.name = defaults.kvNamespaces.FORM_GUARD_KV.name;
	merged.kvNamespaces.SESSION.name = defaults.kvNamespaces.SESSION.name;
	merged.d1Databases.SUBSCRIBERS_DB.databaseName = defaults.d1Databases.SUBSCRIBERS_DB.databaseName;

	return merged;
}

export function writeDeployState(tenantRoot, state) {
	writeJson(resolve(tenantRoot, STATE_PATH), state);
}

export function resolveGeneratedWranglerPath(tenantRoot) {
	return resolve(tenantRoot, GENERATED_WRANGLER_PATH);
}

export function buildWranglerConfigContents(tenantRoot, deployConfig, state) {
	const workerName = state.workerName ?? deriveCloudflareWorkerName(deployConfig);
	const mainPath = relativeFromGeneratedRoot(resolve(tenantRoot, '.treeseed/generated/worker/index.js'));
	const assetsDirectory = relativeFromGeneratedRoot(resolve(tenantRoot, 'dist'));
	const migrationsDir = relativeFromGeneratedRoot(resolve(tenantRoot, 'migrations'));
	const vars = buildPublicVars(deployConfig);

	return [
		`name = ${renderTomlString(workerName)}`,
		`compatibility_date = ${renderTomlString(DEFAULT_COMPATIBILITY_DATE)}`,
		`compatibility_flags = [${DEFAULT_COMPATIBILITY_FLAGS.map((flag) => renderTomlString(flag)).join(', ')}]`,
		`main = ${renderTomlString(mainPath)}`,
		'workers_dev = true',
		'preview_urls = true',
		'',
		'[assets]',
		`directory = ${renderTomlString(assetsDirectory)}`,
		'',
		'[vars]',
		...Object.entries(vars).map(([key, value]) => `${key} = ${renderTomlString(value)}`),
		'',
		'[[kv_namespaces]]',
		'binding = "FORM_GUARD_KV"',
		`id = ${renderTomlString(state.kvNamespaces.FORM_GUARD_KV.id)}`,
		`preview_id = ${renderTomlString(state.kvNamespaces.FORM_GUARD_KV.previewId ?? state.kvNamespaces.FORM_GUARD_KV.id)}`,
		'',
		'[[kv_namespaces]]',
		'binding = "SESSION"',
		`id = ${renderTomlString(state.kvNamespaces.SESSION.id)}`,
		`preview_id = ${renderTomlString(state.kvNamespaces.SESSION.previewId ?? state.kvNamespaces.SESSION.id)}`,
		'',
		'[[d1_databases]]',
		'binding = "SUBSCRIBERS_DB"',
		`database_name = ${renderTomlString(state.d1Databases.SUBSCRIBERS_DB.databaseName)}`,
		`database_id = ${renderTomlString(state.d1Databases.SUBSCRIBERS_DB.databaseId)}`,
		`preview_database_id = ${renderTomlString(state.d1Databases.SUBSCRIBERS_DB.previewDatabaseId ?? state.d1Databases.SUBSCRIBERS_DB.databaseId)}`,
		`migrations_dir = ${renderTomlString(migrationsDir)}`,
		'',
	].join('\n');
}

export function ensureGeneratedWranglerConfig(tenantRoot) {
	const deployConfig = loadTreeseedDeployConfig();
	const state = loadDeployState(tenantRoot, deployConfig);
	const wranglerPath = resolveGeneratedWranglerPath(tenantRoot);
	const manifestFingerprint = stableHash(JSON.stringify(deployConfig));
	const contents = buildWranglerConfigContents(tenantRoot, deployConfig, state);
	ensureParent(wranglerPath);
	writeFileSync(wranglerPath, contents, 'utf8');
	state.lastManifestFingerprint = manifestFingerprint;
	if (!state.generatedSecrets) {
		state.generatedSecrets = {};
	}
	const secretMap = buildSecretMap(deployConfig, state);
	state.generatedSecrets.DOCS_FORM_TOKEN_SECRET = secretMap.DOCS_FORM_TOKEN_SECRET;
	writeDeployState(tenantRoot, state);
	return { wranglerPath, deployConfig, state, manifestFingerprint };
}

function runWrangler(args, { cwd, allowFailure = false, json = false, capture = false, env = {} } = {}) {
	const result = spawnSync(process.execPath, [wranglerBin, ...args], {
		stdio: json || capture ? 'pipe' : 'inherit',
		cwd,
		env: { ...process.env, ...env },
		encoding: 'utf8',
	});

	if (result.status !== 0 && !allowFailure) {
		const stderr = result.stderr?.trim();
		throw new Error(stderr || `Wrangler command failed: ${args.join(' ')}`);
	}

	return result;
}

function parseWranglerAssignment(result, label, field) {
	const source = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
	const pattern = new RegExp(`${field}\\s*=\\s*"([^"]+)"`);
	const match = source.match(pattern);
	if (!match) {
		throw new Error(`Unable to parse ${field} from ${label}.`);
	}
	return match[1];
}

function parseWranglerJsonOutput(result, label) {
	const source = `${result.stdout ?? ''}`.trim();
	if (!source) {
		throw new Error(`Expected JSON output from ${label}.`);
	}
	return JSON.parse(source);
}

function listKvNamespaces(tenantRoot, env) {
	const result = runWrangler(['kv', 'namespace', 'list'], {
		cwd: tenantRoot,
		capture: true,
		env,
	});
	return parseWranglerJsonOutput(result, 'KV namespace list');
}

function listD1Databases(tenantRoot, env) {
	const result = runWrangler(['d1', 'list', '--json'], {
		cwd: tenantRoot,
		capture: true,
		env,
	});
	return parseWranglerJsonOutput(result, 'D1 list');
}

function isPlaceholderResourceId(value) {
	if (!value || typeof value !== 'string') {
		return true;
	}

	return (
		value.startsWith('local-') ||
		value.startsWith('dryrun-') ||
		value.endsWith('-id') ||
		value.endsWith('-preview-id')
	);
}

function buildProvisioningSummary(deployConfig, state) {
	return {
		workerName: state.workerName ?? deriveCloudflareWorkerName(deployConfig),
		siteUrl: deployConfig.siteUrl,
		accountId: deployConfig.cloudflare.accountId,
		formGuardKv: state.kvNamespaces.FORM_GUARD_KV,
		sessionKv: state.kvNamespaces.SESSION,
		subscribersDb: state.d1Databases.SUBSCRIBERS_DB,
	};
}

function isPlaceholderAccountId(value) {
	return !value || value === 'replace-with-cloudflare-account-id';
}

function missingTurnstileRequirements(deployConfig) {
	if (!deployConfig.turnstile?.enabled) {
		return [];
	}

	const issues = [];
	if (!envOrNull('DOCS_PUBLIC_TURNSTILE_SITE_KEY')) {
		issues.push('Set DOCS_PUBLIC_TURNSTILE_SITE_KEY before deploying with turnstile.enabled: true.');
	}
	if (!envOrNull('DOCS_TURNSTILE_SECRET_KEY')) {
		issues.push('Set DOCS_TURNSTILE_SECRET_KEY before deploying with turnstile.enabled: true.');
	}
	return issues;
}

export function validateDeployPrerequisites(tenantRoot, { requireRemote = true } = {}) {
	const deployConfig = loadTreeseedDeployConfig();
	const issues = [];

	if (isPlaceholderAccountId(deployConfig.cloudflare.accountId)) {
		issues.push(
			`Set cloudflare.accountId in ${relative(tenantRoot, deployConfig.__configPath ?? resolve(tenantRoot, 'treeseed.site.yaml'))} or export CLOUDFLARE_ACCOUNT_ID.`,
		);
	}

	if (requireRemote) {
		issues.push(...missingTurnstileRequirements(deployConfig));

		const result = runWrangler(['whoami'], {
			cwd: tenantRoot,
			allowFailure: true,
			capture: true,
		});
		const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
		if (/You are not authenticated/i.test(output) || /wrangler login/i.test(output)) {
			issues.push('Authenticate Wrangler first with `wrangler login`.');
		}
	}

	if (issues.length > 0) {
		throw new Error(`Treeseed deploy prerequisites are not satisfied:\n- ${issues.join('\n- ')}`);
	}

	return deployConfig;
}

export function provisionCloudflareResources(tenantRoot, { dryRun = false } = {}) {
	const deployConfig = loadTreeseedDeployConfig();
	const state = loadDeployState(tenantRoot, deployConfig);
	state.workerName = deriveCloudflareWorkerName(deployConfig);

	const env = {
		CLOUDFLARE_ACCOUNT_ID: deployConfig.cloudflare.accountId,
	};
	const kvNamespaces = dryRun ? [] : listKvNamespaces(tenantRoot, env);
	const d1Databases = dryRun ? [] : listD1Databases(tenantRoot, env);

	const ensureKv = (binding) => {
		const current = state.kvNamespaces[binding];
		if (current?.id && !isPlaceholderResourceId(current.id)) {
			state.kvNamespaces[binding].previewId = current.previewId ?? current.id;
			return;
		}

		const existing = kvNamespaces.find((entry) => entry?.title === current.name);
		if (existing?.id) {
			state.kvNamespaces[binding].id = existing.id;
			state.kvNamespaces[binding].previewId = existing.id;
			return;
		}

		if (dryRun) {
			state.kvNamespaces[binding].id = `dryrun-${current.name}`;
			state.kvNamespaces[binding].previewId = `dryrun-${current.name}-preview`;
			return;
		}

		const args = ['kv', 'namespace', 'create', current.name];
		runWrangler(args, { cwd: tenantRoot, capture: true, env });
		const refreshed = listKvNamespaces(tenantRoot, env);
		const created = refreshed.find((entry) => entry?.title === current.name);
		if (!created?.id) {
			throw new Error(`Unable to resolve created KV namespace id for ${current.name}.`);
		}
		state.kvNamespaces[binding].id = created.id;
		state.kvNamespaces[binding].previewId = created.id;
	};

	const ensureD1 = () => {
		const current = state.d1Databases.SUBSCRIBERS_DB;
		if (current?.databaseId && !isPlaceholderResourceId(current.databaseId)) {
			return;
		}

		const existing = d1Databases.find((entry) => entry?.name === current.databaseName);
		if (existing?.uuid) {
			current.databaseId = existing.uuid;
			current.previewDatabaseId = existing.previewDatabaseUuid ?? existing.uuid;
			return;
		}

		if (dryRun) {
			current.databaseId = `dryrun-${current.databaseName}`;
			current.previewDatabaseId = `dryrun-${current.databaseName}-preview`;
			return;
		}

		runWrangler(['d1', 'create', current.databaseName], {
			cwd: tenantRoot,
			capture: true,
			env,
		});
		const refreshed = listD1Databases(tenantRoot, env);
		const created = refreshed.find((entry) => entry?.name === current.databaseName);
		if (!created?.uuid) {
			throw new Error(`Unable to resolve created D1 database id for ${current.databaseName}.`);
		}
		current.databaseId = created.uuid;
		current.previewDatabaseId = created.previewDatabaseUuid ?? created.uuid;
	};

	ensureKv('FORM_GUARD_KV');
	ensureKv('SESSION');
	ensureD1();

	writeDeployState(tenantRoot, state);
	return buildProvisioningSummary(deployConfig, state);
}

export function syncCloudflareSecrets(tenantRoot, { dryRun = false } = {}) {
	const deployConfig = loadTreeseedDeployConfig();
	const state = loadDeployState(tenantRoot, deployConfig);
	const env = {
		CLOUDFLARE_ACCOUNT_ID: deployConfig.cloudflare.accountId,
	};
	const secrets = buildSecretMap(deployConfig, state);
	const synced = [];

	for (const [key, value] of Object.entries(secrets)) {
		if (!value) {
			continue;
		}

		synced.push(key);
		if (dryRun) {
			continue;
		}

		const result = spawnSync(process.execPath, [wranglerBin, 'secret', 'put', key, '--config', resolveGeneratedWranglerPath(tenantRoot)], {
			cwd: tenantRoot,
			input: `${value}\n`,
			stdio: ['pipe', 'inherit', 'inherit'],
			env: { ...process.env, ...env },
			encoding: 'utf8',
		});

		if (result.status !== 0) {
			throw new Error(`Failed to sync secret ${key}.`);
		}
	}

	state.generatedSecrets = {
		...(state.generatedSecrets ?? {}),
		DOCS_FORM_TOKEN_SECRET: secrets.DOCS_FORM_TOKEN_SECRET ?? state.generatedSecrets?.DOCS_FORM_TOKEN_SECRET,
	};
	writeDeployState(tenantRoot, state);
	return synced;
}

export function runRemoteD1Migrations(tenantRoot, { dryRun = false } = {}) {
	const { wranglerPath, deployConfig, state } = ensureGeneratedWranglerConfig(tenantRoot);
	if (dryRun) {
		return { databaseName: state.d1Databases.SUBSCRIBERS_DB.databaseName, dryRun: true };
	}

	runWrangler(
		['d1', 'migrations', 'apply', state.d1Databases.SUBSCRIBERS_DB.databaseName, '--remote', '--config', wranglerPath],
		{
			cwd: tenantRoot,
			env: { CLOUDFLARE_ACCOUNT_ID: deployConfig.cloudflare.accountId },
		},
	);

	return { databaseName: state.d1Databases.SUBSCRIBERS_DB.databaseName, dryRun: false };
}

export function finalizeDeploymentState(tenantRoot) {
	const deployConfig = loadTreeseedDeployConfig();
	const state = loadDeployState(tenantRoot, deployConfig);
	state.lastManifestFingerprint = stableHash(JSON.stringify(deployConfig));
	state.lastDeployedUrl = deployConfig.siteUrl;
	state.lastDeploymentTimestamp = new Date().toISOString();
	writeDeployState(tenantRoot, state);
	return state;
}

export function printDeploySummary(summary) {
	console.log('Treeseed deployment summary');
	console.log(`  Worker: ${summary.workerName}`);
	console.log(`  Site URL: ${summary.siteUrl}`);
	console.log(`  Account ID: ${summary.accountId}`);
	console.log(`  D1: ${summary.subscribersDb.databaseName} (${summary.subscribersDb.databaseId})`);
	console.log(`  KV FORM_GUARD_KV: ${summary.formGuardKv.id}`);
	console.log(`  KV SESSION: ${summary.sessionKv.id}`);
}
