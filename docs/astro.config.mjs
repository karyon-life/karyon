// @ts-check
import { defineConfig, envField } from 'astro/config';
import { readFileSync } from 'node:fs';
import cloudflare from '@astrojs/cloudflare';
import starlight from '@astrojs/starlight';
import rehypeKatex from 'rehype-katex';
import remarkMath from 'remark-math';
import tailwindcss from '@tailwindcss/vite';
import { parseSiteConfig } from './src/utils/site-config-schema.js';
import { getStarlightSidebarConfig } from './src/utils/starlight-nav.mjs';

const siteConfig = parseSiteConfig(readFileSync(new URL('./src/config.yaml', import.meta.url), 'utf8'));

/**
 * @param {string} publicPath
 */
function toStarlightLogoSrc(publicPath) {
	return publicPath.startsWith('/') ? `./public${publicPath}` : publicPath;
}

/**
 * Normalize common AI-exported LaTeX escaping inside math nodes so KaTeX can render it.
 * @param {string} value
 */
function normalizeEscapedMath(value) {
	return value
		.replace(/\\\\([A-Za-z]+)/g, '\\$1')
		.replace(/\\([\[\]])/g, '$1')
		.replace(/\\left\\([\[\]\(\)])/g, '\\left$1')
		.replace(/\\right\\([\[\]\(\)])/g, '\\right$1')
		.replace(/\\([_=+\-])/g, '$1');
}

/**
 * @param {{ children?: any[] } & Record<string, any>} node
 * @param {(node: any) => void} visitor
 */
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
	/** @param {any} tree */
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

/**
 * Normalize the HAST nodes that `rehype-katex` actually reads during Astro/Starlight rendering.
 */
function rehypeNormalizeEscapedMath() {
	/** @param {any} tree */
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

// https://astro.build/config
export default defineConfig({
	site: siteConfig.site.siteUrl,
	adapter: cloudflare(),
	image: {
		service: {
			entrypoint: 'astro/assets/services/noop',
		},
	},
	vite: {
		plugins: [/** @type {any} */ (tailwindcss())],
	},
	markdown: {
		remarkPlugins: [remarkMath, remarkNormalizeEscapedMath],
		rehypePlugins: [rehypeNormalizeEscapedMath, [rehypeKatex, { strict: 'ignore' }]],
	},
	env: {
		schema: {
			DOCS_PUBLIC_TURNSTILE_SITE_KEY: envField.string({
				context: 'client',
				access: 'public',
				optional: true,
			}),
			DOCS_PUBLIC_FORMS_LOCAL_BYPASS_TURNSTILE: envField.boolean({
				context: 'client',
				access: 'public',
				optional: true,
			}),
			DOCS_TURNSTILE_SECRET_KEY: envField.string({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_SMTP_HOST: envField.string({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_SMTP_PORT: envField.number({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_SMTP_USERNAME: envField.string({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_SMTP_PASSWORD: envField.string({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_SMTP_FROM: envField.string({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_SMTP_REPLY_TO: envField.string({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_FORM_TOKEN_SECRET: envField.string({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_LOCAL_DEV_MODE: envField.enum({
				values: ['cloudflare'],
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_FORMS_LOCAL_BYPASS_TURNSTILE: envField.boolean({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_FORMS_LOCAL_BYPASS_CLOUDFLARE_GUARDS: envField.boolean({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_FORMS_LOCAL_USE_MAILPIT: envField.boolean({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_MAILPIT_SMTP_HOST: envField.string({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
			DOCS_MAILPIT_SMTP_PORT: envField.number({
				context: 'server',
				access: 'secret',
				optional: true,
			}),
		},
	},
	integrations: [
		starlight({
			customCss: ['./src/styles/global.css'],
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
				Footer: './src/components/docs/Footer.astro',
				Header: './src/components/docs/Header.astro',
				PageTitle: './src/components/docs/PageTitle.astro',
				PageFrame: './src/components/docs/PageFrame.astro',
				PageSidebar: './src/components/docs/PageSidebar.astro',
				Sidebar: './src/components/docs/Sidebar.astro',
				SiteTitle: './src/components/SiteTitle.astro',
				ThemeSelect: './src/components/docs/ThemeSelect.astro',
			},
			sidebar: getStarlightSidebarConfig(),
			routeMiddleware: ['./src/middleware/starlightRouteData.ts'],
		}),
	],
});
