export const DOCS_LINKS = {
	home: '/docs/',
};

const RESEARCH_BOOK = {
	slug: 'research',
	label: 'Research',
	description:
		'Topic-organized research reports that ground Karyon and provide reusable source material for multiple books over time.',
	basePath: '/docs/research/',
	landingPath: '/docs/research/',
	sectionLabel: 'Research',
	downloadFileName: 'research.md',
	downloadHref: '/books/research.md',
	downloadTitle: 'Karyon Research',
	exportRoots: [
		'src/content/docs/docs/research/index.mdx',
		'src/content/docs/docs/research/foundations',
		'src/content/docs/docs/research/learning',
		'src/content/docs/docs/research/runtime',
		'src/content/docs/docs/research/memory',
		'src/content/docs/docs/research/perception',
		'src/content/docs/docs/research/autonomy',
		'src/content/docs/docs/research/execution',
		'src/content/docs/docs/research/observability',
	],
	sidebarItems: [
		{ label: 'Overview', link: '/docs/research/' },
		{
			label: 'Foundations',
			autogenerate: { directory: 'docs/research/foundations' },
		},
		{
			label: 'Learning',
			autogenerate: { directory: 'docs/research/learning' },
		},
		{
			label: 'Runtime',
			autogenerate: { directory: 'docs/research/runtime' },
		},
		{
			label: 'Memory',
			autogenerate: { directory: 'docs/research/memory' },
		},
		{
			label: 'Perception',
			autogenerate: { directory: 'docs/research/perception' },
		},
		{
			label: 'Autonomy',
			autogenerate: { directory: 'docs/research/autonomy' },
		},
		{
			label: 'Execution',
			autogenerate: { directory: 'docs/research/execution' },
		},
		{
			label: 'Observability',
			autogenerate: { directory: 'docs/research/observability' },
		},
	],
};

const ARCHITECTURE_BOOK = {
	slug: 'architecture',
	label: 'Architecture',
	description:
		'The architecture book and technical thesis behind Karyon’s biomimetic, cellular, graph-oriented design.',
	basePath: '/docs/architecture/',
	landingPath: '/docs/architecture/',
	outlinePath: '/docs/architecture/topic-outline/',
	sectionLabel: 'Architecture',
	downloadFileName: 'architecture.md',
	downloadHref: '/books/architecture.md',
	downloadTitle: 'Karyon Architecture',
	exportRoots: [
		'src/content/docs/docs/architecture/index.mdx',
		'src/content/docs/docs/architecture/topic-outline.md',
		'src/content/docs/docs/architecture/part-1',
		'src/content/docs/docs/architecture/part-2',
		'src/content/docs/docs/architecture/part-3',
		'src/content/docs/docs/architecture/part-4',
		'src/content/docs/docs/architecture/part-5',
		'src/content/docs/docs/architecture/part-6',
	],
	sidebarItems: [
		{ label: 'Overview', link: '/docs/architecture/' },
		{ label: 'Topic Outline', link: '/docs/architecture/topic-outline/' },
		{
			label: 'Part I: The Biological Edge in Systems',
			items: [
				{
					label: 'Chapter 1: The Problem with Transformers',
					autogenerate: { directory: 'docs/architecture/part-1/chapter-1' },
				},
				{
					label: 'Chapter 2: Principles of Biological Intelligence',
					autogenerate: { directory: 'docs/architecture/part-1/chapter-2' },
				},
			],
		},
		{
			label: 'Part II: Anatomy of the Organism',
			items: [
				{
					label: 'Chapter 3: The Karyon Kernel (Nucleus)',
					autogenerate: { directory: 'docs/architecture/part-2/chapter-3' },
				},
				{
					label: 'Chapter 4: Digital DNA & Epigenetics',
					autogenerate: { directory: 'docs/architecture/part-2/chapter-4' },
				},
			],
		},
		{
			label: 'Part III: The Rhizome (Memory & Learning)',
			items: [
				{
					label: 'Chapter 5: The Extracellular Matrix (Topology)',
					autogenerate: { directory: 'docs/architecture/part-3/chapter-5' },
				},
				{
					label: 'Chapter 6: Synaptic Plasticity & Consolidation',
					autogenerate: { directory: 'docs/architecture/part-3/chapter-6' },
				},
			],
		},
		{
			label: 'Part IV: Perception and Action',
			items: [
				{
					label: 'Chapter 7: Sensory Organs (I/O Constraints)',
					autogenerate: { directory: 'docs/architecture/part-4/chapter-7' },
				},
				{
					label: 'Chapter 8: Motor Functions and Validation',
					autogenerate: { directory: 'docs/architecture/part-4/chapter-8' },
				},
			],
		},
		{
			label: 'Part V: Consciousness and Autonomy',
			items: [
				{
					label: 'Chapter 9: Digital Metabolism & Needs',
					autogenerate: { directory: 'docs/architecture/part-5/chapter-9' },
				},
				{
					label: 'Chapter 10: Sovereign Architecture & Symbiosis',
					autogenerate: { directory: 'docs/architecture/part-5/chapter-10' },
				},
			],
		},
		{
			label: 'Part VI: Maturation & Lifecycle Execution',
			items: [
				{
					label: 'Chapter 11: Bootstrapping Karyon',
					autogenerate: { directory: 'docs/architecture/part-6/chapter-11' },
				},
				{
					label: 'Chapter 12: The Training Curriculum',
					autogenerate: { directory: 'docs/architecture/part-6/chapter-12' },
				},
			],
		},
	],
};

const DEVELOPER_BOOK = {
	slug: 'developer',
	label: 'Developer',
	description:
		'Contributor-facing notes, implementation context, and source-guided references for working inside the Karyon codebase.',
	basePath: '/docs/developer/',
	landingPath: '/docs/developer/',
	sectionLabel: 'Developer',
	downloadFileName: 'developer.md',
	downloadHref: '/books/developer.md',
	downloadTitle: 'Karyon Developer',
	exportRoots: [
		'src/content/docs/docs/developer/index.mdx',
		'src/content/docs/docs/developer/nif-safety.md',
		'src/content/docs/docs/developer/subsystem-contracts.md',
		'src/content/docs/docs/developer/learning-loop.md',
		'src/content/docs/docs/developer/monorepo-pipeline.md',
		'src/content/docs/docs/developer/operational-maturity.md',
		'src/content/docs/docs/developer/maturation-lifecycle.md',
		'src/content/docs/docs/developer/chapter-1-conformance.md',
		'src/content/docs/docs/developer/chapter-2-conformance.md',
		'src/content/docs/docs/developer/chapter-3-conformance.md',
		'src/content/docs/docs/developer/chapter-4-conformance.md',
		'src/content/docs/docs/developer/chapter-5-conformance.md',
		'src/content/docs/docs/developer/chapter-6-conformance.md',
		'src/content/docs/docs/developer/chapter-7-conformance.md',
		'src/content/docs/docs/developer/chapter-8-conformance.md',
		'src/content/docs/docs/developer/chapter-9-conformance.md',
		'src/content/docs/docs/developer/chapter-10-conformance.md',
		'src/content/docs/docs/developer/chapter-11-conformance.md',
		'src/content/docs/docs/developer/chapter-12-conformance.md',
	],
	sidebarItems: [
		{ label: 'Overview', link: '/docs/developer/' },
		{
			label: 'Core References',
			items: [
				{ label: 'NIF Safety', link: '/docs/developer/nif-safety/' },
				{ label: 'Subsystem Contracts', link: '/docs/developer/subsystem-contracts/' },
				{ label: 'Learning Loop', link: '/docs/developer/learning-loop/' },
				{ label: 'Monorepo Pipeline', link: '/docs/developer/monorepo-pipeline/' },
				{ label: 'Operational Maturity', link: '/docs/developer/operational-maturity/' },
				{ label: 'Maturation Lifecycle', link: '/docs/developer/maturation-lifecycle/' },
			],
		},
		{
			label: 'Conformance References',
			items: [
				{ label: 'Chapter 1 Conformance', link: '/docs/developer/chapter-1-conformance/' },
				{ label: 'Chapter 2 Conformance', link: '/docs/developer/chapter-2-conformance/' },
				{ label: 'Chapter 3 Conformance', link: '/docs/developer/chapter-3-conformance/' },
				{ label: 'Chapter 4 Conformance', link: '/docs/developer/chapter-4-conformance/' },
				{ label: 'Chapter 5 Conformance', link: '/docs/developer/chapter-5-conformance/' },
				{ label: 'Chapter 6 Conformance', link: '/docs/developer/chapter-6-conformance/' },
				{ label: 'Chapter 7 Conformance', link: '/docs/developer/chapter-7-conformance/' },
				{ label: 'Chapter 8 Conformance', link: '/docs/developer/chapter-8-conformance/' },
				{ label: 'Chapter 9 Conformance', link: '/docs/developer/chapter-9-conformance/' },
				{ label: 'Chapter 10 Conformance', link: '/docs/developer/chapter-10-conformance/' },
				{ label: 'Chapter 11 Conformance', link: '/docs/developer/chapter-11-conformance/' },
				{ label: 'Chapter 12 Conformance', link: '/docs/developer/chapter-12-conformance/' },
			],
		},
	],
};

const OPERATIONS_BOOK = {
	slug: 'operations',
	label: 'Operations',
	description:
		'Operational context, readiness framing, and the practical constraints currently shaping how Karyon is expected to run.',
	basePath: '/docs/operations/',
	landingPath: '/docs/operations/',
	sectionLabel: 'Operations',
	downloadFileName: 'operations.md',
	downloadHref: '/books/operations.md',
	downloadTitle: 'Karyon Operations',
	exportRoots: [
		'src/content/docs/docs/operations/index.mdx',
		'src/content/docs/docs/operations/health.md',
		'src/content/docs/docs/operations/capacity.md',
		'src/content/docs/docs/operations/metabolics.md',
		'src/content/docs/docs/operations/baselines.md',
		'src/content/docs/docs/operations/releases.md',
		'src/content/docs/docs/operations/genetics.md',
	],
	sidebarItems: [
		{ label: 'Overview', link: '/docs/operations/' },
		{ label: 'Health', link: '/docs/operations/health/' },
		{ label: 'Capacity', link: '/docs/operations/capacity/' },
		{ label: 'Metabolics', link: '/docs/operations/metabolics/' },
		{ label: 'Baselines', link: '/docs/operations/baselines/' },
		{ label: 'Releases', link: '/docs/operations/releases/' },
		{ label: 'Genetics', link: '/docs/operations/genetics/' },
	],
};

export const BOOKS = [
	RESEARCH_BOOK,
	ARCHITECTURE_BOOK,
	DEVELOPER_BOOK,
	OPERATIONS_BOOK,
	// Add future books here when they have real content and a public landing page.
];

export const BOOKS_LINK = {
	label: 'Books',
	link: DOCS_LINKS.home,
};

export const DOCS_LIBRARY_DOWNLOAD = {
	downloadFileName: 'karyon-docs.md',
	downloadHref: '/books/karyon-docs.md',
	downloadTitle: 'Karyon Docs Library',
};

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
