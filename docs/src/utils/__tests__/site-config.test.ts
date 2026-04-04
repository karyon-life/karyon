import { describe, expect, it } from 'vitest';
import {
	SITE_CONFIG,
	applyDocsModelDefaults,
	applyNoteModelDefaults,
	applyPageModelDefaults,
} from '../site-config';
import { parseSiteConfig } from '../site-config-schema.js';

describe('site config parsing', () => {
	it('loads grouped header and footer menus from config.yaml', () => {
		expect(SITE_CONFIG.site.headerMenu.length).toBeGreaterThan(0);
		expect(SITE_CONFIG.site.headerMenu[0].label).toBe('Work');
		expect(SITE_CONFIG.site.headerMenu[0].items).toContainEqual({
			label: 'Architecture',
			href: '/architecture/',
		});
		expect(SITE_CONFIG.site.footerMenu.length).toBeGreaterThan(0);
	});

	it('requires core site metadata fields', () => {
		expect(() =>
			parseSiteConfig(`
site:
  logo:
    src: /logo.png
    alt: Example logo
  statement: Example statement
  siteUrl: https://example.com
  githubRepository: https://github.com/example/repo
  discordLink: https://discord.gg/example
  headerMenu:
    - label: Explore
      items:
        - label: Home
          href: /
  footerMenu:
    - label: Explore
      items:
        - label: Home
          href: /
  emailNotifications:
    contactRouting:
      default:
        - hello@example.com
    subscribeRecipients:
      - hello@example.com
  summary: Example summary
  projectStage: Founding
  projectStageDetail: Still early
models: {}
			`),
		).toThrow('site.name');
	});

	it('applies content model defaults as fallbacks', () => {
		const page = applyPageModelDefaults({
			status: 'live',
		});
		const note = applyNoteModelDefaults({
			status: 'live',
		});
		const docs = applyDocsModelDefaults({});

		expect(page.pageLayout).toBe(SITE_CONFIG.models.pages.defaults.pageLayout);
		expect(page.stage).toBe(SITE_CONFIG.models.pages.defaults.stage);
		expect(page.audience).toEqual(SITE_CONFIG.models.pages.defaults.audience);
		expect(note.author).toBe(SITE_CONFIG.models.notes.defaults.author);
		expect(note.draft).toBe(SITE_CONFIG.models.notes.defaults.draft);
		expect(note.tags).toEqual(SITE_CONFIG.models.notes.defaults.tags);
		expect(docs.tags).toEqual(SITE_CONFIG.models.docs.defaults.tags);
	});

	it('extracts email notification mappings from config.yaml', () => {
		expect(SITE_CONFIG.site.emailNotifications.contactRouting.default).toEqual(['contact@karyon.life']);
		expect(SITE_CONFIG.site.emailNotifications.contactRouting.issue).toEqual(['contact@karyon.life']);
		expect(SITE_CONFIG.site.emailNotifications.subscribeRecipients).toEqual(['contact@karyon.life']);
	});
});
