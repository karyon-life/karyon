import { describe, expect, it } from 'vitest';
import {
	formatCliPreflightReport,
	parseCopilotSessionStatus,
	parseGitHubAuthStatus,
	parseWranglerWhoAmI,
} from '../../scripts/workspace-preflight-lib.mjs';

describe('workspace preflight helpers', () => {
	it('parses gh auth status output', () => {
		expect(parseGitHubAuthStatus('Active account: true\nLogged in to github.com', 0).authenticated).toBe(true);
		expect(parseGitHubAuthStatus('The token in default is invalid.', 1).authenticated).toBe(false);
	});

	it('parses wrangler auth output', () => {
		expect(parseWranglerWhoAmI('You are logged in with an API Token', 0).authenticated).toBe(true);
		expect(parseWranglerWhoAmI('fetch failed', 1).authenticated).toBe(false);
	});

	it('parses copilot session configuration output', () => {
		expect(parseCopilotSessionStatus('Copilot token environment variable detected.', 0).configured).toBe(true);
		expect(parseCopilotSessionStatus('No Copilot token environment variable detected.', 1).configured).toBe(false);
	});

	it('formats a readable preflight report', () => {
		const output = formatCliPreflightReport({
			ok: false,
			requireAuth: true,
			missingCommands: ['gh'],
			failingAuth: ['wrangler'],
			checks: {
				commands: {
					git: { installed: true, path: '/usr/bin/git' },
					gh: { installed: false, path: null },
				},
				auth: {
					gh: { authenticated: false, detail: 'invalid token' },
					wrangler: { authenticated: false, detail: 'fetch failed' },
					copilot: { configured: true, detail: 'token present' },
				},
			},
		});

		expect(output).toContain('Treeseed preflight summary');
		expect(output).toContain('Missing commands: gh');
		expect(output).toContain('Auth failures: wrangler');
	});
});
