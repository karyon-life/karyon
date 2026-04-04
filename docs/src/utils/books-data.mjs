import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { parse as parseYaml } from 'yaml';

const projectRoot = process.cwd();
const booksContentRoot = path.join(projectRoot, 'src', 'content', 'books');

function sortPaths(paths) {
	return [...paths].sort((left, right) => left.localeCompare(right, undefined, { numeric: true, sensitivity: 'base' }));
}

function collectBookFiles(rootPath) {
	const stats = statSync(rootPath);
	if (stats.isFile()) {
		return [rootPath];
	}

	return sortPaths(
		readdirSync(rootPath, { withFileTypes: true }).flatMap((entry) => {
			const fullPath = path.join(rootPath, entry.name);
			if (entry.isDirectory()) {
				return collectBookFiles(fullPath);
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

function loadBooks() {
	return collectBookFiles(booksContentRoot)
		.map((filePath) => {
			const frontmatter = parseFrontmatter(filePath);
			return {
				...frontmatter,
				id: path.basename(filePath, path.extname(filePath)),
			};
		})
		.sort((left, right) => left.order - right.order);
}

export const BOOKS = loadBooks();
export const BOOKS_LINK = {
	label: 'Books',
	link: '/docs/',
};

export const DOCS_LINKS = {
	home: '/docs/',
};

export const DOCS_LIBRARY_DOWNLOAD = {
	downloadFileName: 'karyon-docs.md',
	downloadHref: '/books/karyon-docs.md',
	downloadTitle: 'Karyon Docs Library',
};
