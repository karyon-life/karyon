export const SITE_NAV_GROUPS = [
	{
		label: 'Work',
		items: [
			{ href: '/architecture/', label: 'Architecture' },
			{ href: '/docs/', label: 'Docs' },
			{ href: '/contribute/', label: 'Contribute' },
		],
	},
	{
		label: 'Thinking',
		items: [
			{ href: '/research-direction/', label: 'Research Direction' },
			{ href: '/notes/', label: 'Notes' },
		],
	},
	{
		label: 'Resources',
		items: [
			{ href: '/docs/research/', label: 'Research Book' },
			{ href: '/docs/architecture/', label: 'Architecture Book' },
			{ href: '/docs/developer/', label: 'Developer Book' },
			{ href: '/docs/operations/', label: 'Operations Book' },
		],
	},
	{
		label: 'About',
		items: [
			{ href: '/vision/', label: 'Vision' },
			{ href: '/status/', label: 'Project Status' },
			{ href: '/community/', label: 'Community' },
		],
	},
] as const;

export function normalizeSitePath(path: string) {
	return path.endsWith('/') ? path : `${path}/`;
}

export function isCurrentSitePath(currentPath: string, href: string) {
	return normalizeSitePath(currentPath) === normalizeSitePath(href);
}

export function groupContainsCurrentPath(
	currentPath: string,
	group: (typeof SITE_NAV_GROUPS)[number],
) {
	return group.items.some((item) => isCurrentSitePath(currentPath, item.href));
}
