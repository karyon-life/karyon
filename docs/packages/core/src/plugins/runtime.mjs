import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadTreeseedDeployConfig } from '../deploy/config.mjs';
import { TREESEED_DEFAULT_PLUGIN_PACKAGE } from './constants.mjs';
import builtinDefaultPlugin from './builtin/default-plugin.mjs';

const require = createRequire(import.meta.url);

function normalizeLoadedPlugin(moduleExports, packageName) {
	const plugin = moduleExports?.default ?? moduleExports;
	if (!plugin || typeof plugin !== 'object') {
		throw new Error(`Treeseed plugin "${packageName}" did not export a plugin object.`);
	}
	return plugin;
}

function isPathLikePluginReference(packageName) {
	return packageName.startsWith('.') || packageName.startsWith('/') || packageName.startsWith('file:');
}

function loadPluginModule(packageName, tenantRoot) {
	if (packageName === TREESEED_DEFAULT_PLUGIN_PACKAGE) {
		return builtinDefaultPlugin;
	}

	if (isPathLikePluginReference(packageName)) {
		const resolvedPath = packageName.startsWith('file:')
			? fileURLToPath(packageName)
			: path.resolve(tenantRoot, packageName);
		return require(resolvedPath);
	}

	return require(packageName);
}

export function loadTreeseedPlugins(config = loadTreeseedDeployConfig()) {
	const tenantRoot = config.__tenantRoot ?? process.cwd();
	const plugins = [];

	for (const pluginRef of config.plugins ?? []) {
		if (pluginRef?.enabled === false) {
			continue;
		}

		const loaded = loadPluginModule(pluginRef.package, tenantRoot);
		const plugin = normalizeLoadedPlugin(loaded, pluginRef.package);
		plugins.push({
			package: pluginRef.package,
			config: pluginRef.config ?? {},
			plugin,
		});
	}

	return plugins;
}

function collectProvidedIds(plugins) {
	const provided = {
		forms: new Set(),
		agents: {
			execution: new Set(),
			mutation: new Set(),
			repository: new Set(),
			verification: new Set(),
			notification: new Set(),
			research: new Set(),
			handlers: new Set(),
		},
		deploy: new Set(),
		content: {
			docs: new Set(),
		},
		site: new Set(),
	};

	for (const { plugin } of plugins) {
		for (const id of plugin.provides?.forms ?? []) provided.forms.add(id);
		for (const id of plugin.provides?.agents?.execution ?? []) provided.agents.execution.add(id);
		for (const id of plugin.provides?.agents?.mutation ?? []) provided.agents.mutation.add(id);
		for (const id of plugin.provides?.agents?.repository ?? []) provided.agents.repository.add(id);
		for (const id of plugin.provides?.agents?.verification ?? []) provided.agents.verification.add(id);
		for (const id of plugin.provides?.agents?.notification ?? []) provided.agents.notification.add(id);
		for (const id of plugin.provides?.agents?.research ?? []) provided.agents.research.add(id);
		for (const id of plugin.provides?.agents?.handlers ?? []) provided.agents.handlers.add(id);
		for (const id of plugin.provides?.deploy ?? []) provided.deploy.add(id);
		for (const id of plugin.provides?.content?.docs ?? []) provided.content.docs.add(id);
		for (const id of plugin.provides?.site ?? []) provided.site.add(id);
	}

	return provided;
}

function assertSelectedProvider(provided, label, id) {
	if (!id) {
		throw new Error(`Treeseed plugin runtime is missing selected provider id for ${label}.`);
	}
	if (!provided.has(id)) {
		throw new Error(`Treeseed plugin runtime could not resolve ${label} provider "${id}".`);
	}
}

export function loadTreeseedPluginRuntime(config = loadTreeseedDeployConfig()) {
	const plugins = loadTreeseedPlugins(config);
	const provided = collectProvidedIds(plugins);
	const providers = config.providers;

	assertSelectedProvider(provided.forms, 'forms', providers.forms);
	assertSelectedProvider(provided.agents.execution, 'agents.execution', providers.agents.execution);
	assertSelectedProvider(provided.agents.mutation, 'agents.mutation', providers.agents.mutation);
	assertSelectedProvider(provided.agents.repository, 'agents.repository', providers.agents.repository);
	assertSelectedProvider(provided.agents.verification, 'agents.verification', providers.agents.verification);
	assertSelectedProvider(provided.agents.notification, 'agents.notification', providers.agents.notification);
	assertSelectedProvider(provided.agents.research, 'agents.research', providers.agents.research);
	assertSelectedProvider(provided.deploy, 'deploy', providers.deploy);
	assertSelectedProvider(provided.content.docs, 'content.docs', providers.content?.docs);
	assertSelectedProvider(provided.site, 'site', providers.site);

	return {
		config,
		plugins,
		provided,
	};
}
