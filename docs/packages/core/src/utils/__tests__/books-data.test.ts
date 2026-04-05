import { describe, expect, it } from 'vitest';
import { BOOKS } from '../books-data.mjs';
import { buildBookSidebar, getBookForPath, getDocsDownloadForPath } from '../starlight-nav.mjs';

describe('book metadata integration', () => {
	it('loads books from content entries in stable order', () => {
		expect(BOOKS.map((book: (typeof BOOKS)[number]) => book.slug)).toEqual([
			'research',
			'architecture',
			'developer',
			'operations',
		]);
	});

	it('builds starlight sidebar groups from book content metadata', () => {
		expect(buildBookSidebar('research')).toMatchObject({
			label: 'Research',
		});
		expect(buildBookSidebar('architecture').items.length).toBeGreaterThan(1);
	});

	it('resolves active book and download metadata from knowledge paths', () => {
		expect(getBookForPath('/knowledge/research/learning/')).toMatchObject({ slug: 'research' });
		expect(getDocsDownloadForPath('/knowledge/architecture/')).toMatchObject({
			downloadFileName: 'architecture.md',
		});
	});
});
