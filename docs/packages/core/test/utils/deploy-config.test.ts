import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { afterEach, describe, expect, it } from 'vitest';
import { deriveCloudflareWorkerName, loadTreeseedDeployConfig } from '../../src/deploy/config';
import { ensureGeneratedWranglerConfig } from '../../scripts/deploy-lib.mjs';

const originalCwd = process.cwd();

afterEach(() => {
	process.chdir(originalCwd);
});

async function createTenantFixture() {
	const tenantRoot = await mkdtemp(join(tmpdir(), 'treeseed-deploy-'));
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
forms:
  mode: notify_admin
agents:
  mode: manual
smtp:
  enabled: true
turnstile:
  enabled: true
`,
	);
	return tenantRoot;
}

describe('deploy config', () => {
	it('loads deploy defaults and derives the worker name', async () => {
		const tenantRoot = await createTenantFixture();
		try {
			process.chdir(tenantRoot);
			const config = loadTreeseedDeployConfig();

			expect(config.forms?.mode).toBe('notify_admin');
			expect(config.agents?.mode).toBe('manual');
			expect(config.cloudflare.accountId).toBe('account-123');
			expect(deriveCloudflareWorkerName(config)).toBe('example-site');
		} finally {
			await rm(tenantRoot, { recursive: true, force: true });
		}
	});

	it('renders a generated wrangler config and persists deploy state', async () => {
		const tenantRoot = await createTenantFixture();
		try {
			process.chdir(tenantRoot);
			const { wranglerPath } = ensureGeneratedWranglerConfig(tenantRoot);
			const wranglerToml = await readFile(wranglerPath, 'utf8');
			const deployState = await readFile(join(tenantRoot, '.treeseed/state/deploy.json'), 'utf8');

			expect(wranglerToml).toContain('binding = "FORM_GUARD_KV"');
			expect(wranglerToml).toContain('binding = "SESSION"');
			expect(wranglerToml).toContain('binding = "SITE_DATA_DB"');
			expect(wranglerToml).toContain('DOCS_AGENT_EXECUTION_MODE = "manual"');
			expect(deployState).toContain('"workerName": "example-site"');
		} finally {
			await rm(tenantRoot, { recursive: true, force: true });
		}
	});
});
