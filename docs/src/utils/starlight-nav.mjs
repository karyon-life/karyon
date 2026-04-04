import { BOOKS, BOOKS_LINK, DOCS_LIBRARY_DOWNLOAD, DOCS_LINKS } from './books-data.mjs';

export { BOOKS, BOOKS_LINK, DOCS_LIBRARY_DOWNLOAD, DOCS_LINKS };

export const normalizeHref = (href) => (href.endsWith('/') ? href : `${href}/`);

export function buildBookSidebar(bookSlug) {
	const book = BOOKS.find((candidate) => candidate.slug === bookSlug);
	if (!book) {
		throw new Error(`Unknown book slug: ${bookSlug}`);
	}

	return {
		label: book.sectionLabel,
		items: book.sidebarItems,
	};
}

export function getStarlightSidebarConfig() {
	return [BOOKS_LINK, ...BOOKS.map((book) => buildBookSidebar(book.slug))];
}

export function getBookForPath(pathname) {
	const normalizedPath = normalizeHref(pathname);
	return BOOKS.find((book) => normalizedPath.startsWith(normalizeHref(book.basePath)));
}

export function getDocsDownloadForPath(pathname) {
	const normalizedPath = normalizeHref(pathname);

	if (normalizedPath === normalizeHref(DOCS_LINKS.home)) {
		return DOCS_LIBRARY_DOWNLOAD;
	}

	const book = getBookForPath(normalizedPath);
	if (!book) {
		return null;
	}

	return {
		downloadFileName: book.downloadFileName,
		downloadHref: book.downloadHref,
		downloadTitle: book.downloadTitle,
	};
}
