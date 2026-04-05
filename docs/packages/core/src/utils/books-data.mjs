import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { parse as parseYaml } from 'yaml';
import { getTenantContentRoot } from '../tenant/config.mjs';
import { RUNTIME_PROJECT_ROOT, RUNTIME_TENANT } from '../tenant/runtime-config.mjs';

function sortPaths(paths) {
	return [...paths].sort((left, right) => left.localeCompare(right, undefined, { numeric: true, sensitivity: 'base' }));
}

function collectMarkdownFiles(rootPath) {
	const stats = statSync(rootPath);
	if (stats.isFile()) {
		return [rootPath];
	}

	return sortPaths(
		readdirSync(rootPath, { withFileTypes: true }).flatMap((entry) => {
			const fullPath = path.join(rootPath, entry.name);
			if (entry.isDirectory()) {
				return collectMarkdownFiles(fullPath);
			}

			if (entry.isFile() && (entry.name.endsWith('.md') || entry.name.endsWith('.mdx'))) {
				return [fullPath];
			}

			return [];
		}),
	);
}

function parseFrontmatter(filePath) {
	const raw = readFileSync(filePath, 'utf8');
	const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---/);
	if (!match) {
		throw new Error(`Book content entry is missing frontmatter: ${filePath}`);
	}

	return parseYaml(match[1]);
}

/**
 * @param {{ slug?: string, title?: string }} book
 */
function inferDocsLibraryDownload(book) {
	const title = book?.title ? `${book.title} Library` : 'Knowledge Library';
	return {
		downloadFileName: 'karyon-knowledge.md',
		downloadHref: '/books/karyon-knowledge.md',
		downloadTitle: title,
	};
}

/**
 * @param {{ content: Record<string, string> }} tenantConfig
 * @param {{ projectRoot?: string, docsHomePath?: string, docsLibraryDownload?: { downloadFileName: string, downloadHref: string, downloadTitle: string } }} [options]
 */
export function buildTenantBookRuntime(tenantConfig, options = {}) {
	const projectRoot = options.projectRoot ?? process.cwd();
	const booksContentRoot = path.resolve(projectRoot, getTenantContentRoot(tenantConfig, 'books'));
	const books = collectMarkdownFiles(booksContentRoot)
		.map((filePath) => {
			const frontmatter = parseFrontmatter(filePath);
			return {
				...frontmatter,
				id: path.basename(filePath, path.extname(filePath)),
			};
		})
		.sort((left, right) => left.order - right.order);

	const docsHomePath = options.docsHomePath ?? '/knowledge/';
	const docsLibraryDownload = options.docsLibraryDownload ?? inferDocsLibraryDownload(tenantConfig);

	return {
		BOOKS: books,
		BOOKS_LINK: {
			label: 'Books',
			link: docsHomePath,
		},
		DOCS_LINKS: {
			home: docsHomePath,
		},
		DOCS_LIBRARY_DOWNLOAD: docsLibraryDownload,
	};
}

const runtime = buildTenantBookRuntime(RUNTIME_TENANT, {
		projectRoot: RUNTIME_PROJECT_ROOT,
		docsLibraryDownload: {
		downloadFileName: 'karyon-knowledge.md',
		downloadHref: '/books/karyon-knowledge.md',
		downloadTitle: 'Karyon Knowledge Library',
		},
});

export const { BOOKS, BOOKS_LINK, DOCS_LINKS, DOCS_LIBRARY_DOWNLOAD } = runtime;
