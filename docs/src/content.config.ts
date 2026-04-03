import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';

const statusValues = ['live', 'in progress', 'exploratory', 'planned', 'speculative'] as const;
const pageLayoutValues = ['article', 'bridge'] as const;

const pages = defineCollection({
	loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/pages' }),
	schema: z.object({
		title: z.string(),
		description: z.string(),
		slug: z.string(),
		pageLayout: z.enum(pageLayoutValues).default('article'),
		status: z.enum(statusValues),
		stage: z.literal('founding'),
		audience: z.array(z.string()),
		summary: z.string(),
		updated: z.coerce.date(),
		seoTitle: z.string().optional(),
		seoDescription: z.string().optional(),
	}),
});

const notes = defineCollection({
	loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/notes' }),
	schema: z.object({
		title: z.string(),
		description: z.string(),
		date: z.coerce.date(),
		status: z.enum(statusValues),
		tags: z.array(z.string()).default([]),
		author: z.string(),
		summary: z.string(),
		draft: z.boolean().default(false),
		canonicalRoute: z.string().optional(),
	}),
});

export const collections = {
	pages,
	notes,
	docs: defineCollection({
		loader: docsLoader(),
		schema: docsSchema({
			extend: z.object({
				tags: z.array(z.string()).default([]),
			}),
		}),
	}),
};
