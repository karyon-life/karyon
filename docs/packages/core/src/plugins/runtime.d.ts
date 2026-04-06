import type { TreeseedDeployConfig } from '../contracts';

export function loadTreeseedPlugins(config?: TreeseedDeployConfig): Array<{
	package: string;
	config: Record<string, unknown>;
	plugin: Record<string, unknown>;
}>;

export function loadTreeseedPluginRuntime(config?: TreeseedDeployConfig): {
	config: TreeseedDeployConfig;
	plugins: ReturnType<typeof loadTreeseedPlugins>;
	provided: Record<string, unknown>;
};
