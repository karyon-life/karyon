import { defineConfig, envField } from 'astro/config';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import rehypeKatex from 'rehype-katex';
import remarkMath from 'remark-math';
import tailwindcss from '@tailwindcss/vite';
import { parseSiteConfig } from './utils/site-config-schema.js';
import { buildTenantBookRuntime } from './utils/books-data.mjs';
import { getStarlightSidebarConfigFromRuntime } from './utils/starlight-nav.mjs';
import { buildTenantThemeCss } from './utils/theme.ts';
import { loadTreeseedDeployConfig } from './deploy/config.mjs';

const TENANT_THEME_VIRTUAL_ID = 'virtual:treeseed/tenant-theme.css';
const RESOLVED_TENANT_THEME_VIRTUAL_ID = '\0treeseed:tenant-theme.css';

function packageFile(relativePath) {
	return fileURLToPath(new URL(relativePath, import.meta.url));
}

function packageModuleFile(relativeStem) {
	for (const extension of ['.js', '.mjs', '.ts']) {
		const candidateUrl = new URL(`${relativeStem}${extension}`, import.meta.url);
		const candidatePath = fileURLToPath(candidateUrl);
		if (existsSync(candidatePath)) {
			return candidatePath;
		}
	}

	throw new Error(`Unable to resolve package module for ${relativeStem}`);
}

const PACKAGE_ROUTE_ENTRIES = [
	{ pattern: '/', entrypoint: packageFile('./pages/index.astro') },
	{ pattern: '/404', entrypoint: packageFile('./pages/404.astro') },
	{ pattern: '/contact', entrypoint: packageFile('./pages/contact.astro') },
	{ pattern: '/feed.xml', entrypoint: packageModuleFile('./pages/feed.xml') },
	{ pattern: '/[slug]', entrypoint: packageFile('./pages/[slug].astro') },
	{ pattern: '/agents', entrypoint: packageFile('./pages/agents/index.astro') },
	{ pattern: '/agents/[slug]', entrypoint: packageFile('./pages/agents/[slug].astro') },
	{ pattern: '/books', entrypoint: packageFile('./pages/books/index.astro') },
	{ pattern: '/books/[slug]', entrypoint: packageFile('./pages/books/[slug].astro') },
	{ pattern: '/notes', entrypoint: packageFile('./pages/notes/index.astro') },
	{ pattern: '/notes/[slug]', entrypoint: packageFile('./pages/notes/[slug].astro') },
	{ pattern: '/objectives', entrypoint: packageFile('./pages/objectives/index.astro') },
	{ pattern: '/objectives/[slug]', entrypoint: packageFile('./pages/objectives/[slug].astro') },
	{ pattern: '/people', entrypoint: packageFile('./pages/people/index.astro') },
	{ pattern: '/people/[slug]', entrypoint: packageFile('./pages/people/[slug].astro') },
	{ pattern: '/questions', entrypoint: packageFile('./pages/questions/index.astro') },
	{ pattern: '/questions/[slug]', entrypoint: packageFile('./pages/questions/[slug].astro') },
];

function createTreeseedRoutesIntegration(tenantConfig) {
	return {
		name: 'treeseed-routes',
		hooks: {
			'astro:config:setup'({ injectRoute }) {
				for (const route of PACKAGE_ROUTE_ENTRIES) {
					if (route.pattern.startsWith('/agents') && tenantConfig.features?.agents === false) continue;
					if (route.pattern.startsWith('/books') && tenantConfig.features?.books === false) continue;
					if (route.pattern.startsWith('/notes') && tenantConfig.features?.notes === false) continue;
					if (route.pattern.startsWith('/objectives') && tenantConfig.features?.objectives === false) continue;
					if (route.pattern.startsWith('/questions') && tenantConfig.features?.questions === false) continue;
					injectRoute(route);
				}
			},
		},
	};
}

function toStarlightLogoSrc(publicPath) {
	return publicPath.startsWith('/') ? `./public${publicPath}` : publicPath;
}

function createTenantThemeVitePlugin(themeCss) {
	return {
		name: 'treeseed-tenant-theme',
		resolveId(id) {
			return id === TENANT_THEME_VIRTUAL_ID ? RESOLVED_TENANT_THEME_VIRTUAL_ID : undefined;
		},
		load(id) {
			return id === RESOLVED_TENANT_THEME_VIRTUAL_ID ? themeCss : undefined;
		},
	};
}

function normalizeEscapedMath(value) {
	return value
		.replace(/\\\\([A-Za-z]+)/g, '\\$1')
		.replace(/\\([\[\]])/g, '$1')
		.replace(/\\left\\([\[\]\(\)])/g, '\\left$1')
		.replace(/\\right\\([\[\]\(\)])/g, '\\right$1')
		.replace(/\\([_=+\-])/g, '$1');
}

function walkTree(node, visitor) {
	visitor(node);
	if (!node || !Array.isArray(node.children)) {
		return;
	}

	for (const child of node.children) {
		walkTree(child, visitor);
	}
}

function remarkNormalizeEscapedMath() {
	return (tree) => {
		walkTree(tree, (node) => {
			if ((node.type === 'math' || node.type === 'inlineMath') && typeof node.value === 'string') {
				const normalizedValue = normalizeEscapedMath(node.value);
				node.value = normalizedValue;

				if (node.data && Array.isArray(node.data.hChildren)) {
					for (const child of node.data.hChildren) {
						if (child && child.type === 'text' && typeof child.value === 'string') {
							child.value = normalizedValue;
						}
					}
				}
			}
		});
	};
}

function rehypeNormalizeEscapedMath() {
	return (tree) => {
		walkTree(tree, (node) => {
			if (node?.type !== 'element' || node.tagName !== 'code') {
				return;
			}

			const classNames = Array.isArray(node.properties?.className) ? node.properties.className : [];
			if (!classNames.includes('language-math')) {
				return;
			}

			if (!Array.isArray(node.children)) {
				return;
			}

			for (const child of node.children) {
				if (child?.type === 'text' && typeof child.value === 'string') {
					child.value = normalizeEscapedMath(child.value);
				}
			}
		});
	};
}

export function createTreeseedSite(tenantConfig, { starlight }) {
	const projectRoot = process.cwd();
	const siteConfig = parseSiteConfig(readFileSync(resolve(projectRoot, tenantConfig.siteConfigPath), 'utf8'));
	const deployConfig = loadTreeseedDeployConfig();
	const bookRuntime = buildTenantBookRuntime(tenantConfig, { projectRoot });
	const tenantThemeCss = buildTenantThemeCss(siteConfig.site.theme);
	const injectedTenantConfig = JSON.stringify(tenantConfig);
	const injectedProjectRoot = JSON.stringify(projectRoot);
	const injectedSiteConfig = JSON.stringify(siteConfig);
	const injectedDeployConfig = JSON.stringify(deployConfig);

	return defineConfig({
		output: 'static',
		site: siteConfig.site.siteUrl,
		vite: {
			define: {
				__TREESEED_TENANT_CONFIG__: injectedTenantConfig,
				__TREESEED_PROJECT_ROOT__: injectedProjectRoot,
				__TREESEED_SITE_CONFIG__: injectedSiteConfig,
				__TREESEED_DEPLOY_CONFIG__: injectedDeployConfig,
			},
			plugins: [
				createTenantThemeVitePlugin(tenantThemeCss),
				/** @type {any} */ (tailwindcss()),
			],
			ssr: {
				external: ['node:fs', 'node:path', 'node:url'],
			},
		},
		markdown: {
			syntaxHighlight: false,
			remarkPlugins: [remarkMath, remarkNormalizeEscapedMath],
			rehypePlugins: [rehypeNormalizeEscapedMath, [rehypeKatex, { strict: 'ignore' }]],
		},
		env: {
			schema: {
				TREESEED_PUBLIC_TURNSTILE_SITE_KEY: envField.string({ context: 'client', access: 'public', optional: true }),
				TREESEED_PUBLIC_FORMS_LOCAL_BYPASS_TURNSTILE: envField.boolean({ context: 'client', access: 'public', optional: true }),
				TREESEED_PUBLIC_DEV_WATCH_RELOAD: envField.boolean({ context: 'client', access: 'public', optional: true }),
				TREESEED_TURNSTILE_SECRET_KEY: envField.string({ context: 'server', access: 'secret', optional: true }),
				TREESEED_SMTP_HOST: envField.string({ context: 'server', access: 'secret', optional: true }),
				TREESEED_SMTP_PORT: envField.number({ context: 'server', access: 'secret', optional: true }),
				TREESEED_SMTP_USERNAME: envField.string({ context: 'server', access: 'secret', optional: true }),
				TREESEED_SMTP_PASSWORD: envField.string({ context: 'server', access: 'secret', optional: true }),
				TREESEED_SMTP_FROM: envField.string({ context: 'server', access: 'secret', optional: true }),
				TREESEED_SMTP_REPLY_TO: envField.string({ context: 'server', access: 'secret', optional: true }),
				TREESEED_FORM_TOKEN_SECRET: envField.string({ context: 'server', access: 'secret', optional: true }),
				TREESEED_LOCAL_DEV_MODE: envField.enum({ values: ['cloudflare'], context: 'server', access: 'secret', optional: true }),
				TREESEED_FORMS_LOCAL_BYPASS_TURNSTILE: envField.boolean({ context: 'server', access: 'secret', optional: true }),
				TREESEED_FORMS_LOCAL_BYPASS_CLOUDFLARE_GUARDS: envField.boolean({ context: 'server', access: 'secret', optional: true }),
				TREESEED_FORMS_LOCAL_USE_MAILPIT: envField.boolean({ context: 'server', access: 'secret', optional: true }),
				TREESEED_MAILPIT_SMTP_HOST: envField.string({ context: 'server', access: 'secret', optional: true }),
				TREESEED_MAILPIT_SMTP_PORT: envField.number({ context: 'server', access: 'secret', optional: true }),
			},
		},
		integrations: [
			createTreeseedRoutesIntegration(tenantConfig),
			starlight({
				disable404Route: true,
				expressiveCode: false,
				customCss: [packageFile('./styles/global.css'), TENANT_THEME_VIRTUAL_ID],
				title: siteConfig.site.name,
				logo: {
					src: toStarlightLogoSrc(siteConfig.site.logo.src),
					alt: siteConfig.site.logo.alt,
				},
				social: [
					{ icon: 'github', label: `${siteConfig.site.name} GitHub`, href: siteConfig.site.githubRepository },
					{ icon: 'discord', label: `${siteConfig.site.name} Discord`, href: siteConfig.site.discordLink },
				],
				components: {
					Footer: packageFile('./components/docs/Footer.astro'),
					Header: packageFile('./components/docs/Header.astro'),
					PageTitle: packageFile('./components/docs/PageTitle.astro'),
					PageFrame: packageFile('./components/docs/PageFrame.astro'),
					PageSidebar: packageFile('./components/docs/PageSidebar.astro'),
					Sidebar: packageFile('./components/docs/Sidebar.astro'),
					SiteTitle: packageFile('./components/SiteTitle.astro'),
					ThemeSelect: packageFile('./components/docs/ThemeSelect.astro'),
				},
				sidebar: getStarlightSidebarConfigFromRuntime(bookRuntime),
				routeMiddleware: [packageModuleFile('./middleware/starlightRouteData')],
			}),
		],
	});
}
