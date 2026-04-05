export type TreeseedFeatureName =
	| 'docs'
	| 'books'
	| 'notes'
	| 'questions'
	| 'objectives'
	| 'agents'
	| 'forms';

export type TreeseedContentCollection =
	| 'pages'
	| 'notes'
	| 'questions'
	| 'objectives'
	| 'people'
	| 'agents'
	| 'books'
	| 'docs';

export interface TreeseedFeatureModules {
	docs?: boolean;
	books?: boolean;
	notes?: boolean;
	questions?: boolean;
	objectives?: boolean;
	agents?: boolean;
	forms?: boolean;
	[key: string]: boolean | undefined;
}

export interface TreeseedContentMap {
	pages: string;
	notes: string;
	questions: string;
	objectives: string;
	people: string;
	agents: string;
	books: string;
	docs: string;
}

export interface TreeseedBookDefinition {
	order: number;
	slug: string;
	title: string;
	description: string;
	summary: string;
	sectionLabel: string;
	basePath: string;
	landingPath: string;
	outlinePath?: string;
	downloadFileName: string;
	downloadHref: string;
	downloadTitle: string;
	exportRoots?: string[];
	sidebarItems: Array<{
		label: string;
		link?: string;
		autogenerate?: { directory: string };
		items?: TreeseedBookDefinition['sidebarItems'];
	}>;
	tags?: string[];
	id?: string;
}

export interface TreeseedThemeConfig {
	surfaces?: {
		background?: string;
		backgroundElevated?: string;
		backgroundSoft?: string;
		panel?: string;
		panelStrong?: string;
	};
	text?: {
		body?: string;
		muted?: string;
		soft?: string;
	};
	border?: {
		base?: string;
		strong?: string;
		grid?: string;
	};
	accent?: {
		base?: string;
		strong?: string;
		soft?: string;
	};
	info?: {
		base?: string;
		strong?: string;
		soft?: string;
	};
	warm?: {
		base?: string;
		strong?: string;
	};
}

export interface TreeseedTenantConfig {
	id: string;
	siteConfigPath: string;
	content: TreeseedContentMap;
	features: TreeseedFeatureModules;
	overrides?: {
		components?: Record<string, string>;
		styles?: string[];
		routes?: string[];
	};
}
