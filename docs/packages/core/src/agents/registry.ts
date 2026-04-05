import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { AGENT_HANDLER_KINDS, type AgentHandlerKind } from '../types/agents';
import type { AgentHandler } from '../utils/agents/runtime-types.ts';
import { resolveTreeseedTenantRoot } from '../tenant/config.mjs';

const HANDLER_EXPORT_NAMES: Record<AgentHandlerKind, string> = {
	planner: 'plannerHandler',
	architect: 'architectHandler',
	engineer: 'engineerHandler',
	notifier: 'notifierHandler',
	researcher: 'researcherHandler',
	reviewer: 'reviewerHandler',
	releaser: 'releaserHandler',
};

export function getTenantAgentHandlerModulePath(
	kind: AgentHandlerKind,
	tenantRoot = resolveTreeseedTenantRoot(),
) {
	return resolve(tenantRoot, 'src/agents', `${kind}.ts`);
}

export async function loadTenantAgentHandlerRegistry(
	tenantRoot = resolveTreeseedTenantRoot(),
): Promise<Partial<Record<AgentHandlerKind, AgentHandler>>> {
	const registry: Partial<Record<AgentHandlerKind, AgentHandler>> = {};

	for (const kind of AGENT_HANDLER_KINDS) {
		const modulePath = getTenantAgentHandlerModulePath(kind, tenantRoot);
		if (!existsSync(modulePath)) {
			continue;
		}

		let moduleExports: Record<string, unknown>;
		try {
			moduleExports = await import(/* @vite-ignore */ pathToFileURL(modulePath).href);
		} catch (error) {
			const reason = error instanceof Error ? error.message : String(error);
			throw new Error(`Failed to import tenant agent handler "${kind}" from ${modulePath}: ${reason}`);
		}

		const exportName = HANDLER_EXPORT_NAMES[kind];
		const handler = moduleExports[exportName];
		if (!handler) {
			throw new Error(
				`Tenant agent handler module "${modulePath}" must export "${exportName}" for handler kind "${kind}".`,
			);
		}

		const normalizedHandler = handler as AgentHandler;
		if (normalizedHandler.kind !== kind) {
			throw new Error(
				`Tenant agent handler "${exportName}" from "${modulePath}" declares kind "${normalizedHandler.kind}", but "${kind}" was expected.`,
			);
		}

		registry[kind] = normalizedHandler;
	}

	return registry;
}

export const AGENT_HANDLER_REGISTRY = await loadTenantAgentHandlerRegistry();

export function resolveAgentHandler(kind: AgentHandlerKind) {
	const handler = AGENT_HANDLER_REGISTRY[kind];
	if (!handler) {
		const expectedPath = getTenantAgentHandlerModulePath(kind);
		const expectedExport = HANDLER_EXPORT_NAMES[kind];
		throw new Error(
			`No runtime handler is registered for agent handler "${kind}". Expected tenant file "${expectedPath}" exporting "${expectedExport}".`,
		);
	}

	return handler;
}
