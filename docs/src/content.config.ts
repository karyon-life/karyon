import { defineCollection, reference, z } from 'astro:content';
import { glob } from 'astro/loaders';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import {
	AGENT_MODEL_DEFAULTS,
	BOOK_MODEL_DEFAULTS,
	DOCS_MODEL_DEFAULTS,
	NOTE_MODEL_DEFAULTS,
	OBJECTIVE_MODEL_DEFAULTS,
	PAGE_MODEL_DEFAULTS,
	PEOPLE_MODEL_DEFAULTS,
	QUESTION_MODEL_DEFAULTS,
} from './utils/site-config';

const statusValues = ['live', 'in progress', 'exploratory', 'planned', 'speculative'] as const;
const pageLayoutValues = ['article', 'bridge'] as const;
const questionTypeValues = ['research', 'implementation', 'strategy', 'evaluation'] as const;
const timeHorizonValues = ['near-term', 'mid-term', 'long-term'] as const;
const runtimeStatusValues = ['active', 'experimental', 'dormant'] as const;
const agentTriggerTypeValues = ['schedule', 'message', 'follow', 'startup'] as const;
const agentHandlerValues = [
	'planner',
	'architect',
	'engineer',
	'notifier',
	'researcher',
	'reviewer',
	'releaser',
] as const;
const agentPermissionOperationValues = [
	'get',
	'search',
	'follow',
	'pick',
	'create',
	'update',
] as const;

function withOptionalDefault<T extends z.ZodTypeAny>(
	schema: T,
	defaultValue: z.input<T> | undefined,
) {
	return defaultValue === undefined ? schema : schema.default(defaultValue);
}

const contributorReference = z.union([reference('people'), reference('agents')]);

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

export const questionSchema = z.object({
	title: z.string(),
	description: z.string(),
	date: z.coerce.date(),
	status: withOptionalDefault(
		z.enum(statusValues),
		QUESTION_MODEL_DEFAULTS.status as (typeof statusValues)[number] | undefined,
	),
	tags: z.array(z.string()).default(QUESTION_MODEL_DEFAULTS.tags ?? []),
	summary: z.string(),
	draft: z.boolean().default(QUESTION_MODEL_DEFAULTS.draft ?? false),
	questionType: z.enum(questionTypeValues),
	motivation: z.string(),
	primaryContributor: contributorReference,
	relatedObjectives: z.array(reference('objectives')).default([]),
	relatedBooks: z.array(reference('books')).default([]),
});

const questions = defineCollection({
	loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/questions' }),
	schema: questionSchema,
});

export const objectiveSchema = z.object({
	title: z.string(),
	description: z.string(),
	date: z.coerce.date(),
	status: withOptionalDefault(
		z.enum(statusValues),
		OBJECTIVE_MODEL_DEFAULTS.status as (typeof statusValues)[number] | undefined,
	),
	tags: z.array(z.string()).default(OBJECTIVE_MODEL_DEFAULTS.tags ?? []),
	summary: z.string(),
	draft: z.boolean().default(OBJECTIVE_MODEL_DEFAULTS.draft ?? false),
	timeHorizon: z.enum(timeHorizonValues),
	motivation: z.string(),
	primaryContributor: contributorReference,
	relatedQuestions: z.array(reference('questions')).default([]),
	relatedBooks: z.array(reference('books')).default([]),
});

const objectives = defineCollection({
	loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/objectives' }),
	schema: objectiveSchema,
});

const profileLinkSchema = z.object({
	label: z.string(),
	href: z.string(),
});

const agentCliSchema = z.object({
	model: z.string().optional(),
	allowTools: z.array(z.string()).default([]),
	additionalArgs: z.array(z.string()).default([]),
});

const agentTriggerSchema = z.object({
	type: z.enum(agentTriggerTypeValues),
	cron: z.string().optional(),
	messageTypes: z.array(z.string()).default([]),
	models: z.array(z.string()).default([]),
	sinceField: z.string().optional(),
	runOnStart: z.boolean().default(false),
});

const agentPermissionSchema = z.object({
	model: z.string(),
	operations: z.array(z.enum(agentPermissionOperationValues)).min(1),
});

const agentExecutionSchema = z.object({
	maxConcurrency: z.number().int().positive().default(1),
	timeoutSeconds: z.number().int().positive().default(900),
	cooldownSeconds: z.number().int().nonnegative().default(30),
	leaseSeconds: z.number().int().positive().default(300),
	retryLimit: z.number().int().nonnegative().default(3),
	branchPrefix: z.string().default('agent'),
});

const agentTriggerPolicySchema = z.object({
	maxRunsPerCycle: z.number().int().positive().optional(),
	messageBatchSize: z.number().int().positive().optional(),
});

const agentOutputSchema = z.object({
	messageTypes: z.array(z.string()).default([]),
	modelMutations: z.array(z.string()).default([]),
});

export const peopleSchema = z.object({
	name: z.string(),
	description: z.string(),
	summary: z.string(),
	role: z.string(),
	affiliation: z.string(),
	status: withOptionalDefault(
		z.enum(statusValues),
		PEOPLE_MODEL_DEFAULTS.status as (typeof statusValues)[number] | undefined,
	),
	tags: z.array(z.string()).default(PEOPLE_MODEL_DEFAULTS.tags ?? []),
	links: z.array(profileLinkSchema).default([]),
	relatedQuestions: z.array(reference('questions')).default([]),
	relatedObjectives: z.array(reference('objectives')).default([]),
});

const people = defineCollection({
	loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/people' }),
	schema: peopleSchema,
});

export const agentSchema = z.object({
	name: z.string(),
	slug: z.string(),
	handler: z.enum(agentHandlerValues),
	enabled: z.boolean().default(true),
	description: z.string(),
	summary: z.string(),
	operator: z.string(),
	runtimeStatus: withOptionalDefault(
		z.enum(runtimeStatusValues),
		AGENT_MODEL_DEFAULTS.runtimeStatus as (typeof runtimeStatusValues)[number] | undefined,
	),
	capabilities: z.array(z.string()).default([]),
	tags: z.array(z.string()).default(AGENT_MODEL_DEFAULTS.tags ?? []),
	links: z.array(profileLinkSchema).default([]),
	relatedQuestions: z.array(reference('questions')).default([]),
	relatedObjectives: z.array(reference('objectives')).default([]),
	systemPrompt: z.string(),
	persona: z.string(),
	cli: agentCliSchema.default({ allowTools: [], additionalArgs: [] }),
	triggers: z.array(agentTriggerSchema).min(1),
	triggerPolicy: agentTriggerPolicySchema.optional(),
	permissions: z.array(agentPermissionSchema).min(1),
	execution: agentExecutionSchema.default({}),
	outputs: agentOutputSchema.default({}),
});

const agents = defineCollection({
	loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/agents' }),
	schema: agentSchema,
});

const sidebarItemSchema: z.ZodType<any> = z.lazy(() =>
	z.object({
		label: z.string(),
		link: z.string().optional(),
		autogenerate: z.object({ directory: z.string() }).optional(),
		items: z.array(sidebarItemSchema).optional(),
	}),
);

export const bookSchema = z.object({
	order: z.number().int().nonnegative(),
	slug: z.string(),
	title: z.string(),
	description: z.string(),
	summary: z.string(),
	sectionLabel: z.string(),
	basePath: z.string(),
	landingPath: z.string(),
	outlinePath: z.string().optional(),
	downloadFileName: z.string(),
	downloadHref: z.string(),
	downloadTitle: z.string(),
	exportRoots: z.array(z.string()).min(1).optional(),
	sidebarItems: z.array(sidebarItemSchema).min(1),
	tags: z.array(z.string()).default(BOOK_MODEL_DEFAULTS.tags ?? []),
});

const books = defineCollection({
	loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/books' }),
	schema: bookSchema,
});

export const docsExtensionSchema = z.object({
	tags: z.array(z.string()).default(DOCS_MODEL_DEFAULTS.tags ?? []),
});

export const collections = {
	pages,
	notes,
	questions,
	objectives,
	people,
	agents,
	books,
	docs: defineCollection({
		loader: docsLoader(),
		schema: docsSchema({
			extend: docsExtensionSchema,
		}),
	}),
};
