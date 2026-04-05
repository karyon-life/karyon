import type { TreeseedAgentMode, TreeseedDeployConfig, TreeseedFormsMode } from '../contracts';
import { loadTreeseedDeployConfig } from './config';

declare const __TREESEED_DEPLOY_CONFIG__: TreeseedDeployConfig | undefined;

let cachedDeployConfig: TreeseedDeployConfig | null = null;

function defaultDeployConfig(): TreeseedDeployConfig {
	return {
		name: 'Treeseed Site',
		slug: 'treeseed-site',
		siteUrl: 'https://example.com',
		contactEmail: 'contact@example.com',
		cloudflare: {
			accountId: '',
			workerName: 'treeseed-site',
		},
		forms: {
			mode: 'store_only',
		},
		agents: {
			mode: 'stub',
		},
		smtp: {
			enabled: false,
		},
		turnstile: {
			enabled: false,
		},
	};
}

export function getTreeseedDeployConfig() {
	if (cachedDeployConfig) {
		return cachedDeployConfig;
	}

	if (typeof __TREESEED_DEPLOY_CONFIG__ !== 'undefined' && __TREESEED_DEPLOY_CONFIG__) {
		cachedDeployConfig = __TREESEED_DEPLOY_CONFIG__;
		return cachedDeployConfig;
	}

	try {
		cachedDeployConfig = loadTreeseedDeployConfig();
		return cachedDeployConfig;
	} catch {
		cachedDeployConfig = defaultDeployConfig();
		return cachedDeployConfig;
	}
}

export function resetTreeseedDeployConfigForTests() {
	cachedDeployConfig = null;
}

export function getTreeseedFormsMode(): TreeseedFormsMode {
	return getTreeseedDeployConfig().forms?.mode ?? 'store_only';
}

export function getTreeseedAgentMode(): TreeseedAgentMode {
	return getTreeseedDeployConfig().agents?.mode ?? 'stub';
}

export function isTreeseedSmtpEnabled() {
	return getTreeseedDeployConfig().smtp?.enabled ?? false;
}

export function isTreeseedTurnstileEnabled() {
	return getTreeseedDeployConfig().turnstile?.enabled ?? false;
}
