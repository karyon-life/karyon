import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { afterEach, describe, expect, it } from 'vitest';
import {
	CopilotExecutionAdapter,
	createExecutionAdapter,
	ManualExecutionAdapter,
	StubExecutionAdapter,
} from '../../../src/utils/agents/adapters/execution';
import { resetTreeseedDeployConfigForTests } from '../../../src/deploy/runtime';

const originalCwd = process.cwd();
const originalMode = process.env.TREESEED_AGENT_EXECUTION_MODE;

afterEach(() => {
	process.chdir(originalCwd);
	resetTreeseedDeployConfigForTests();
	if (originalMode === undefined) {
		delete process.env.TREESEED_AGENT_EXECUTION_MODE;
	} else {
		process.env.TREESEED_AGENT_EXECUTION_MODE = originalMode;
	}
});

async function createTenantFixture(agentMode = 'stub') {
	const tenantRoot = await mkdtemp(join(tmpdir(), 'treeseed-agent-mode-'));
	await mkdir(join(tenantRoot, 'src'), { recursive: true });
	await writeFile(join(tenantRoot, 'src/manifest.yaml'), 'id: test-site\nsiteConfigPath: ./src/config.yaml\ncontent:\n  pages: ./src/content/pages\n  notes: ./src/content/notes\n  questions: ./src/content/questions\n  objectives: ./src/content/objectives\n  people: ./src/content/people\n  agents: ./src/content/agents\n  books: ./src/content/books\n  docs: ./src/content/knowledge\nfeatures:\n  docs: true\n  books: true\n  notes: true\n  questions: true\n  objectives: true\n  agents: true\n  forms: true\n');
	await writeFile(
		join(tenantRoot, 'treeseed.site.yaml'),
		`name: Example Site
slug: example-site
siteUrl: https://example.com
contactEmail: hello@example.com
cloudflare:
  accountId: account-123
agents:
  mode: ${agentMode}
`,
	);
	return tenantRoot;
}

describe('execution adapter selection', () => {
	it('defaults to stub mode from the deploy config', async () => {
		const tenantRoot = await createTenantFixture('stub');
		try {
			process.chdir(tenantRoot);
			delete process.env.TREESEED_AGENT_EXECUTION_MODE;
			expect(createExecutionAdapter()).toBeInstanceOf(StubExecutionAdapter);
		} finally {
			await rm(tenantRoot, { recursive: true, force: true });
		}
	});

	it('supports manual mode from the deploy config', async () => {
		const tenantRoot = await createTenantFixture('manual');
		try {
			process.chdir(tenantRoot);
			delete process.env.TREESEED_AGENT_EXECUTION_MODE;
			expect(createExecutionAdapter()).toBeInstanceOf(ManualExecutionAdapter);
		} finally {
			await rm(tenantRoot, { recursive: true, force: true });
		}
	});

	it('still allows explicit copilot opt-in via env override', async () => {
		const tenantRoot = await createTenantFixture('stub');
		try {
			process.chdir(tenantRoot);
			process.env.TREESEED_AGENT_EXECUTION_MODE = 'copilot';
			expect(createExecutionAdapter()).toBeInstanceOf(CopilotExecutionAdapter);
		} finally {
			await rm(tenantRoot, { recursive: true, force: true });
		}
	});
});
