import type { TreeseedDeployConfig } from '../contracts';

export type LoadedTreeseedPluginEntry = {
	package: string;
	config: Record<string, unknown>;
	baseDir: string;
	plugin: Record<string, unknown>;
};

export function loadTreeseedPlugins(config?: TreeseedDeployConfig): LoadedTreeseedPluginEntry[];

export function loadTreeseedPluginRuntime(config?: TreeseedDeployConfig): {
	config: TreeseedDeployConfig;
	plugins: ReturnType<typeof loadTreeseedPlugins>;
	provided: Record<string, unknown>;
};
