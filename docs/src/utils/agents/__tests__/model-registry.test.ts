import { describe, expect, it } from 'vitest';
import { MODEL_REGISTRY, resolveModelDefinition } from '../model-registry';

describe('model registry', () => {
	it('maps docs requests onto the public knowledge model alias', () => {
		expect(resolveModelDefinition('docs').name).toBe('knowledge');
		expect(resolveModelDefinition('knowledge').contentCollection).toBe('docs');
	});

	it('defines the expected public models', () => {
		expect(Object.keys(MODEL_REGISTRY).sort()).toEqual([
			'agent',
			'book',
			'knowledge',
			'message',
			'note',
			'objective',
			'question',
			'subscription',
		]);
	});
});
