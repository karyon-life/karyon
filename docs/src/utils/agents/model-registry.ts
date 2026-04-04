import path from 'node:path';
import type { SdkModelDefinition, SdkModelName } from './sdk-types';

const contentRoot = path.resolve(process.cwd(), 'src', 'content');

export const MODEL_REGISTRY: Record<SdkModelName, SdkModelDefinition> = {
	note: {
		name: 'note',
		aliases: ['notes'],
		storage: 'content',
		operations: ['get', 'search', 'follow', 'pick', 'create', 'update'],
		filterableFields: ['title', 'status', 'author', 'tags', 'date', 'updated'],
		sortableFields: ['title', 'date', 'updated'],
		pickField: 'date',
		contentCollection: 'notes',
		contentDir: path.join(contentRoot, 'notes'),
	},
	question: {
		name: 'question',
		aliases: ['questions'],
		storage: 'content',
		operations: ['get', 'search', 'follow', 'pick', 'create', 'update'],
		filterableFields: [
			'title',
			'status',
			'tags',
			'date',
			'questionType',
			'relatedObjectives',
			'relatedBooks',
		],
		sortableFields: ['title', 'date', 'updated'],
		pickField: 'date',
		contentCollection: 'questions',
		contentDir: path.join(contentRoot, 'questions'),
	},
	book: {
		name: 'book',
		aliases: ['books'],
		storage: 'content',
		operations: ['get', 'search', 'follow', 'pick', 'create', 'update'],
		filterableFields: ['title', 'slug', 'tags', 'sectionLabel'],
		sortableFields: ['title', 'order', 'updated'],
		pickField: 'order',
		contentCollection: 'books',
		contentDir: path.join(contentRoot, 'books'),
	},
	knowledge: {
		name: 'knowledge',
		aliases: ['docs', 'knowledge-base'],
		storage: 'content',
		operations: ['get', 'search', 'follow', 'pick', 'create', 'update'],
		filterableFields: ['title', 'tags', 'updated', 'slug'],
		sortableFields: ['title', 'updated'],
		pickField: 'updated',
		contentCollection: 'docs',
		contentDir: path.join(contentRoot, 'docs', 'docs'),
	},
	objective: {
		name: 'objective',
		aliases: ['objectives'],
		storage: 'content',
		operations: ['get', 'search', 'follow', 'pick'],
		filterableFields: [
			'title',
			'status',
			'tags',
			'date',
			'timeHorizon',
			'relatedQuestions',
			'relatedBooks',
		],
		sortableFields: ['title', 'date', 'updated'],
		pickField: 'date',
		contentCollection: 'objectives',
		contentDir: path.join(contentRoot, 'objectives'),
	},
	subscription: {
		name: 'subscription',
		aliases: ['subscriptions', 'subscriber', 'subscribers'],
		storage: 'd1',
		operations: ['get', 'search', 'follow', 'pick'],
		filterableFields: ['email', 'status', 'source', 'created_at', 'updated_at'],
		sortableFields: ['email', 'created_at', 'updated_at'],
		pickField: 'updated_at',
	},
	message: {
		name: 'message',
		aliases: ['messages'],
		storage: 'd1',
		operations: ['get', 'search', 'follow', 'pick', 'create'],
		filterableFields: ['type', 'status', 'related_model', 'related_id', 'priority', 'available_at'],
		sortableFields: ['priority', 'available_at', 'created_at', 'updated_at'],
		pickField: 'available_at',
	},
	agent: {
		name: 'agent',
		aliases: ['agents'],
		storage: 'content',
		operations: ['get', 'search', 'follow', 'pick', 'create', 'update'],
		filterableFields: ['slug', 'runtimeStatus', 'tags', 'operator'],
		sortableFields: ['name', 'slug', 'updated'],
		pickField: 'updated',
		contentCollection: 'agents',
		contentDir: path.join(contentRoot, 'agents'),
	},
};

export function resolveModelDefinition(model: string): SdkModelDefinition {
	const directMatch = MODEL_REGISTRY[model as SdkModelName];
	if (directMatch) {
		return directMatch;
	}

	const normalized = model.trim().toLowerCase();
	const aliasMatch = Object.values(MODEL_REGISTRY).find(
		(definition) => definition.aliases.includes(normalized) || definition.name === normalized,
	);
	if (!aliasMatch) {
		throw new Error(`Unknown SDK model "${model}".`);
	}

	return aliasMatch;
}
