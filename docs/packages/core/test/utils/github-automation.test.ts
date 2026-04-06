import { describe, expect, it } from 'vitest';
import {
	parseGitHubRepositoryFromRemote,
	renderDeployWorkflow,
} from '../../scripts/github-automation-lib.mjs';

describe('github automation helpers', () => {
	it('parses ssh and https github remotes', () => {
		expect(parseGitHubRepositoryFromRemote('git@github.com:karyon-life/karyon.git')).toBe('karyon-life/karyon');
		expect(parseGitHubRepositoryFromRemote('https://github.com/karyon-life/karyon.git')).toBe('karyon-life/karyon');
	});

	it('renders a workflow with the requested working directory', () => {
		const rendered = renderDeployWorkflow({ workingDirectory: 'docs' });

		expect(rendered).toContain('working-directory: docs');
		expect(rendered).toContain('cache-dependency-path: docs/package-lock.json');
		expect(rendered).toContain('run: npm run deploy');
	});
});
