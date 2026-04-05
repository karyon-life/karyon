import { chmodSync, copyFileSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, extname, join, relative, resolve } from 'node:path';
import { build } from 'esbuild';
import ts from 'typescript';
import { packageRoot } from './package-tools.mjs';

const require = createRequire(import.meta.url);
const srcRoot = resolve(packageRoot, 'src');
const scriptsRoot = resolve(packageRoot, 'scripts');
const distRoot = resolve(packageRoot, 'dist');

const JS_SOURCE_EXTENSIONS = new Set(['.mjs', '.ts']);
const COPY_EXTENSIONS = new Set(['.astro', '.css', '.d.ts', '.js']);
const BUNDLED_ENTRYPOINTS = new Set([
	resolve(srcRoot, 'config.mjs'),
	resolve(srcRoot, 'content-config.mjs'),
]);
const COMPATIBILITY_BUNDLES = [
	{
		entryPoint: resolve(srcRoot, 'config.mjs'),
		outputPath: resolve(distRoot, 'config.js'),
	},
	{
		entryPoint: resolve(srcRoot, 'content-config.mjs'),
		outputPath: resolve(distRoot, 'content-config.js'),
	},
];

function walkFiles(root) {
	const files = [];
	for (const entry of readdirSync(root, { withFileTypes: true })) {
		const fullPath = join(root, entry.name);
		if (entry.isDirectory()) {
			files.push(...walkFiles(fullPath));
			continue;
		}
		files.push(fullPath);
	}
	return files;
}

function ensureDir(filePath) {
	mkdirSync(dirname(filePath), { recursive: true });
}

function rewriteRuntimeSpecifiers(contents) {
	return contents.replace(/(['"`])(\.[^'"`\n]+)\.(mjs|ts)\1/g, '$1$2.js$1');
}

function rewriteScriptRuntimeSpecifiers(contents) {
	return rewriteRuntimeSpecifiers(contents)
		.replace(/(['"`])\.\.\/src\//g, '$1../')
		.replace(/(['"`])\.\/src\//g, '$1./dist/');
}

async function compileModule(filePath, sourceRoot, outputRoot) {
	const relativePath = relative(sourceRoot, filePath);
	const outputFile = resolve(outputRoot, relativePath.replace(/\.(mjs|ts)$/u, '.js'));
	ensureDir(outputFile);

	const bundled = BUNDLED_ENTRYPOINTS.has(filePath);
	await build({
		entryPoints: [filePath],
		outfile: outputFile,
		platform: 'node',
		format: 'esm',
		bundle: bundled,
		logLevel: 'silent',
		loader: {
			'.jsonc': 'text',
		},
		external: bundled
			? [
					'node:*',
					'astro',
					'astro/*',
					'astro:content',
					'astro/loaders',
					'astro/config',
					'astro/assets/services/noop',
					'@astrojs/cloudflare',
					'@tailwindcss/vite',
					'rehype-katex',
					'remark-math',
			  ]
			: [],
	});

	const builtSource = readFileSync(outputFile, 'utf8');
	writeFileSync(outputFile, rewriteRuntimeSpecifiers(builtSource), 'utf8');
}

async function buildCompatibilityBundle({ entryPoint, outputPath }) {
	await build({
		entryPoints: [entryPoint],
		outfile: outputPath,
		platform: 'node',
		format: 'esm',
		bundle: true,
		logLevel: 'silent',
		banner: {
			js: "import { createRequire as __treeseedCreateRequire } from 'node:module'; const require = __treeseedCreateRequire(import.meta.url);",
		},
		loader: {
			'.jsonc': 'text',
		},
		external: [
			'node:*',
			'astro',
			'astro/*',
			'astro:content',
			'astro/loaders',
			'astro/config',
			'astro/assets/services/noop',
			'@astrojs/cloudflare',
			'@tailwindcss/vite',
			'rehype-katex',
			'remark-math',
		],
	});
}

function copyAsset(filePath, sourceRoot, outputRoot) {
	const outputFile = resolve(outputRoot, relative(sourceRoot, filePath));
	ensureDir(outputFile);
	copyFileSync(filePath, outputFile);

	if (outputFile.endsWith('.astro') || outputFile.endsWith('.d.ts') || outputFile.endsWith('.js')) {
		const contents = readFileSync(outputFile, 'utf8');
		writeFileSync(outputFile, rewriteRuntimeSpecifiers(contents), 'utf8');
	}
}

function copyPackageAsset(packageName, relativePath, outputRelativePath) {
	let packageRootPath;
	try {
		packageRootPath = dirname(require.resolve(`${packageName}/package.json`));
	} catch {
		packageRootPath = dirname(require.resolve(packageName));
	}

	const sourceFile = resolve(packageRootPath, relativePath);
	const outputFile = resolve(packageRoot, outputRelativePath);
	ensureDir(outputFile);
	copyFileSync(sourceFile, outputFile);
}

function transpileScript(filePath) {
	const source = readFileSync(filePath, 'utf8');
	const relativePath = relative(scriptsRoot, filePath);
	const outputFile = resolve(distRoot, 'scripts', relativePath.replace(/\.(mjs|ts)$/u, '.js'));
	const transformed = extname(filePath) === '.ts'
		? ts.transpileModule(source, {
				compilerOptions: {
					module: ts.ModuleKind.ESNext,
					target: ts.ScriptTarget.ES2022,
				},
		  }).outputText
		: source;

	ensureDir(outputFile);
	writeFileSync(outputFile, rewriteScriptRuntimeSpecifiers(transformed), 'utf8');
	chmodSync(outputFile, 0o755);
}

function rewriteDeclarations() {
	for (const filePath of walkFiles(distRoot)) {
		if (!filePath.endsWith('.d.ts')) continue;
		const contents = readFileSync(filePath, 'utf8');
		writeFileSync(filePath, rewriteRuntimeSpecifiers(contents), 'utf8');
	}
}

async function main() {
	rmSync(distRoot, { recursive: true, force: true });
	mkdirSync(distRoot, { recursive: true });

	for (const filePath of walkFiles(srcRoot)) {
		if (filePath.endsWith('.d.ts')) {
			copyAsset(filePath, srcRoot, distRoot);
			continue;
		}

		const extension = extname(filePath);
		if (JS_SOURCE_EXTENSIONS.has(extension)) {
			await compileModule(filePath, srcRoot, distRoot);
			continue;
		}

		if (COPY_EXTENSIONS.has(extension) || filePath.endsWith('.d.ts')) {
			copyAsset(filePath, srcRoot, distRoot);
		}
	}

	for (const filePath of walkFiles(scriptsRoot)) {
		const extension = extname(filePath);
		if (JS_SOURCE_EXTENSIONS.has(extension)) {
			transpileScript(filePath);
		}
	}

	for (const bundle of COMPATIBILITY_BUNDLES) {
		await buildCompatibilityBundle(bundle);
	}

	copyAsset(resolve(packageRoot, 'tsconfigs/strict.json'), packageRoot, distRoot);
	copyPackageAsset('@astrojs/mdx', 'template/content-module-types.d.ts', 'template/content-module-types.d.ts');
	copyPackageAsset('@astrojs/mdx', 'dist/server.js', 'dist/server.js');
	copyPackageAsset('@astrojs/starlight', 'style/anchor-links.css', 'style/anchor-links.css');
	copyPackageAsset('@astrojs/starlight', 'utils/git.ts', 'utils/git.ts');
	copyPackageAsset('@astrojs/starlight', 'utils/gitInlined.ts', 'utils/gitInlined.ts');
	rewriteDeclarations();
}

main().catch((error) => {
	console.error(error instanceof Error ? error.message : String(error));
	process.exit(1);
});
