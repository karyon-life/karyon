import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import { DOCS_MODEL_DEFAULTS, NOTE_MODEL_DEFAULTS, PAGE_MODEL_DEFAULTS } from './utils/site-config';

const statusValues = ['live', 'in progress', 'exploratory', 'planned', 'speculative'] as const;
const pageLayoutValues = ['article', 'bridge'] as const;

function withOptionalDefault<T extends z.ZodTypeAny>(
	schema: T,
	defaultValue: z.input<T> | undefined,
) {
	return defaultValue === undefined ? schema : schema.default(defaultValue);
}

export const pageSchema = z.object({
	title: z.string(),
	description: z.string(),
	slug: z.string(),
	pageLayout: withOptionalDefault(
		z.enum(pageLayoutValues),
		PAGE_MODEL_DEFAULTS.pageLayout as (typeof pageLayoutValues)[number] | undefined,
	),
	status: withOptionalDefault(
		z.enum(statusValues),
		PAGE_MODEL_DEFAULTS.status as (typeof statusValues)[number] | undefined,
	),
	stage: withOptionalDefault(z.string(), PAGE_MODEL_DEFAULTS.stage),
	audience: z.array(z.string()).default(PAGE_MODEL_DEFAULTS.audience ?? []),
	summary: z.string(),
	updated: z.coerce.date(),
	seoTitle: z.string().optional(),
	seoDescription: z.string().optional(),
});

const pages = defineCollection({
	loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/pages' }),
	schema: pageSchema,
});

export const noteSchema = z.object({
	title: z.string(),
	description: z.string(),
	date: z.coerce.date(),
	status: withOptionalDefault(
		z.enum(statusValues),
		NOTE_MODEL_DEFAULTS.status as (typeof statusValues)[number] | undefined,
	),
	tags: z.array(z.string()).default(NOTE_MODEL_DEFAULTS.tags ?? []),
	author: withOptionalDefault(z.string(), NOTE_MODEL_DEFAULTS.author),
	summary: z.string(),
	draft: z.boolean().default(NOTE_MODEL_DEFAULTS.draft ?? false),
	canonicalRoute: z.string().optional(),
});

const notes = defineCollection({
	loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/notes' }),
	schema: noteSchema,
});

export const docsExtensionSchema = z.object({
	tags: z.array(z.string()).default(DOCS_MODEL_DEFAULTS.tags ?? []),
});

export const collections = {
	pages,
	notes,
	docs: defineCollection({
		loader: docsLoader(),
		schema: docsSchema({
			extend: docsExtensionSchema,
		}),
	}),
};
