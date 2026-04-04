import configSource from '../config.yaml?raw';
import { parseSiteConfig } from './site-config-schema.js';

export const SITE_CONFIG = parseSiteConfig(configSource);

export const SITE = {
	logo: SITE_CONFIG.site.logo,
	name: SITE_CONFIG.site.name,
	statement: SITE_CONFIG.site.statement,
	description: SITE_CONFIG.site.summary,
	summary: SITE_CONFIG.site.summary,
	url: SITE_CONFIG.site.siteUrl,
	githubRepository: SITE_CONFIG.site.githubRepository,
	discordLink: SITE_CONFIG.site.discordLink,
	projectStage: SITE_CONFIG.site.projectStage,
	projectStageDetail: SITE_CONFIG.site.projectStageDetail,
	headerMenu: SITE_CONFIG.site.headerMenu,
	footerMenu: SITE_CONFIG.site.footerMenu,
	emailNotifications: SITE_CONFIG.site.emailNotifications,
};

export const SITE_HEADER_MENU = SITE.headerMenu;
export const SITE_FOOTER_MENU = SITE.footerMenu;
export const SITE_EMAIL_NOTIFICATIONS = SITE.emailNotifications;

export const PAGE_MODEL_DEFAULTS = SITE_CONFIG.models.pages.defaults;
export const NOTE_MODEL_DEFAULTS = SITE_CONFIG.models.notes.defaults;
export const DOCS_MODEL_DEFAULTS = SITE_CONFIG.models.docs.defaults;

export function applyPageModelDefaults<
	T extends Partial<{
		pageLayout: string;
		status: string;
		stage: string;
		audience: string[];
	}>,
>(value: T) {
	return {
		...PAGE_MODEL_DEFAULTS,
		...value,
		audience: value.audience ?? PAGE_MODEL_DEFAULTS.audience ?? [],
	};
}

export function applyNoteModelDefaults<
	T extends Partial<{
		author: string;
		draft: boolean;
		tags: string[];
		status: string;
	}>,
>(value: T) {
	return {
		...NOTE_MODEL_DEFAULTS,
		...value,
		tags: value.tags ?? NOTE_MODEL_DEFAULTS.tags ?? [],
	};
}

export function applyDocsModelDefaults<T extends Partial<{ tags: string[] }>>(value: T) {
	return {
		...DOCS_MODEL_DEFAULTS,
		...value,
		tags: value.tags ?? DOCS_MODEL_DEFAULTS.tags ?? [],
	};
}

export type SiteConfig = typeof SITE_CONFIG;
export type SiteMenuGroup = (typeof SITE.headerMenu)[number];
export type SiteMenuItem = SiteMenuGroup['items'][number];
