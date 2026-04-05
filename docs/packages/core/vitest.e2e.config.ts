import { defineConfig } from 'vitest/config';

export default defineConfig({
	test: {
		include: ['test/utils/agents/e2e/**/*.test.ts'],
	},
});
