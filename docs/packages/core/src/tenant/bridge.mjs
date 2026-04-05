import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { loadTreeseedManifest } from './config.mjs';

const registryModuleUrl = pathToFileURL(resolve(process.cwd(), 'src/agents/registry.ts')).href;
const registryModule = await import(registryModuleUrl);

export const PROJECT_TENANT = loadTreeseedManifest();
export const AGENT_HANDLER_REGISTRY = registryModule.AGENT_HANDLER_REGISTRY;
export const resolveAgentHandler = registryModule.resolveAgentHandler;
