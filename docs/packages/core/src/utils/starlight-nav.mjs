export const normalizeHref = (href) => (href.endsWith('/') ? href : `${href}/`);

/**
 * @param {{ BOOKS: any[] }} runtime
 * @param {string} bookSlug
 */
export function buildBookSidebarFromRuntime(runtime, bookSlug) {
	const book = runtime.BOOKS.find((candidate) => candidate.slug === bookSlug);
	if (!book) {
		throw new Error(`Unknown book slug: ${bookSlug}`);
	}

	return {
		label: book.sectionLabel,
		items: book.sidebarItems,
	};
}

/**
 * @param {{ BOOKS_LINK: any, BOOKS: any[] }} runtime
 */
export function getStarlightSidebarConfigFromRuntime(runtime) {
	return [runtime.BOOKS_LINK, ...runtime.BOOKS.map((book) => buildBookSidebarFromRuntime(runtime, book.slug))];
}

/**
 * @param {{ BOOKS: any[] }} runtime
 * @param {string} pathname
 */
export function getBookForPathFromRuntime(runtime, pathname) {
	const normalizedPath = normalizeHref(pathname);
	return runtime.BOOKS.find((book) => normalizedPath.startsWith(normalizeHref(book.basePath)));
}

/**
 * @param {{ TREESEED_LINKS: { home: string }, TREESEED_LIBRARY_DOWNLOAD: any, BOOKS: any[] }} runtime
 * @param {string} pathname
 */
export function getDocsDownloadForPathFromRuntime(runtime, pathname) {
	const normalizedPath = normalizeHref(pathname);

	if (normalizedPath === normalizeHref(runtime.TREESEED_LINKS.home)) {
		return runtime.TREESEED_LIBRARY_DOWNLOAD;
	}

	const book = getBookForPathFromRuntime(runtime, normalizedPath);
	if (!book) {
		return null;
	}

	return {
		downloadFileName: book.downloadFileName,
		downloadHref: book.downloadHref,
		downloadTitle: book.downloadTitle,
	};
}

import { BOOKS, BOOKS_LINK, TREESEED_LIBRARY_DOWNLOAD, TREESEED_LINKS } from './books-data.mjs';

export { BOOKS, BOOKS_LINK, TREESEED_LIBRARY_DOWNLOAD, TREESEED_LINKS };

const runtime = { BOOKS, BOOKS_LINK, TREESEED_LIBRARY_DOWNLOAD, TREESEED_LINKS };

export function buildBookSidebar(bookSlug) {
	return buildBookSidebarFromRuntime(runtime, bookSlug);
}

export function getStarlightSidebarConfig() {
	return getStarlightSidebarConfigFromRuntime(runtime);
}

export function getBookForPath(pathname) {
	return getBookForPathFromRuntime(runtime, pathname);
}

export function getDocsDownloadForPath(pathname) {
	return getDocsDownloadForPathFromRuntime(runtime, pathname);
}
