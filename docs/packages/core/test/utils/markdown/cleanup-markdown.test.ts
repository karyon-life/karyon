import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { normalizeMarkdown } from '../../../scripts/cleanup-markdown.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const fixturesDir = path.join(__dirname, 'fixtures');

async function readFixture(name: string) {
	return fs.readFile(path.join(fixturesDir, name), 'utf8');
}

describe('normalizeMarkdown', () => {
	it('normalizes sloppy research markdown without changing reference anchors', async () => {
		const input = await readFixture('sloppy-research.input.md');
		const expected = await readFixture('sloppy-research.expected.md');

		const normalized = await normalizeMarkdown(input, { filePath: 'sloppy-research.md' });

		expect(normalized).toBe(expected);
		expect(normalized).toContain('1. <a id="ref-1"></a>Source one');
		expect(normalized).toContain('2. <a id="ref-2"></a>Source two');
	});

	it('preserves frontmatter, MDX, math, and reference links', async () => {
		const input = await readFixture('sloppy-mdx.input.mdx');
		const expected = await readFixture('sloppy-mdx.expected.mdx');

		const normalized = await normalizeMarkdown(input, { filePath: 'sloppy-mdx.mdx' });

		expect(normalized).toBe(expected);
		expect(normalized).toContain('$\\\\mathcal{O}(D^{-2})$');
		expect(normalized).toContain('[[1]](#ref-1)');
		expect(normalized).toContain('<Notice />');
	});

	it('is idempotent on already-normalized content', async () => {
		const expected = await readFixture('sloppy-mdx.expected.mdx');

		const normalized = await normalizeMarkdown(expected, { filePath: 'sloppy-mdx.mdx' });

		expect(normalized).toBe(expected);
	});

	it('splits adjacent standalone prose lines into separate paragraphs', async () => {
		const input = `## Summary

First standalone paragraph ends here.
Second standalone paragraph starts here.
**1. Item Title**
*Link/DOI:* [Example](https://example.com)
*Note:* A separate note paragraph.
`;

		const normalized = await normalizeMarkdown(input, { filePath: 'standalone-paragraphs.md' });

		expect(normalized).toContain('First standalone paragraph ends here.\n\nSecond standalone paragraph starts here.');
		expect(normalized).toContain('**1. Item Title**\n\n*Link/DOI:* [Example](https://example.com)\n\n*Note:* A separate note paragraph.');
	});
});
