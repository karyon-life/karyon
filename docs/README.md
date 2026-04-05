# Karyon Knowledge Hub

This site contains the architecture book and operator-facing documentation for Karyon.

This repository is being prepared to stand on its own. Treat the `docs/` directory as the future root of the standalone docs repository even while it still lives inside the runtime monorepo.

## Core vs Payload

The docs app now uses a package-first split:

- `packages/core/`: the main shared Astro site, Starlight integration, components, layouts, routes, middleware, scripts, forms runtime, and generic agent runtime/framework.
- `src/manifest.yaml`: the project tenant manifest.
- `src/content/**`, `src/config.yaml`, `public/`, `prompts/`, and `src/agents/**`: Karyon-owned payload.
- `src/content.config.ts` and `astro.config.mjs`: thin local entrypoints that mount the shared package from the project repo.

The intended steady state is that almost all app/framework code lives in `@treeseed/core`, while project repos mostly carry tenant data, concrete agent definitions/handlers, and tiny entrypoints.

## Current State

The docs describe both the target organism and the codebase that exists today. Treat the codebase as the source of truth for runtime behavior:

- the project-owned knowledge source lives in `src/content/knowledge/`
- the public site routes are injected from `@treeseed/core`, while the platform package patches Starlight to treat `src/content/knowledge/` as the docs collection root
- `public/books/*.md` are generated book exports and are intentionally gitignored
- production-facing integrations such as XTDB, NATS, and Firecracker are still being hardened
- use the runtime repository's `PLAN.md` and `TASKS.md` to track readiness work while the docs still live inside the monorepo

## Standalone-First Workflow

Use docs-local commands from inside `docs/` as the default operating mode:

```bash
cd docs
npm install
```

The docs tenant now has a single runtime dependency in [package.json](/home/adrian/Projects/nexical/karyon/docs/package.json): `@treeseed/core`.

The current nested layout is temporary. Root-level `npm run docs:*` commands remain available only as a transitional wrapper until the docs are moved into their own repository.

## 🚀 Project Structure

Inside of your Astro + Starlight project, you'll see the following folders and files:

```
.
├── public/
├── packages/
│   └── core/
├── src/
│   ├── content/
│   │   ├── knowledge/
│   │   ├── notes/
│   │   └── pages/
│   ├── agents/
│   ├── manifest.yaml
│   └── content.config.ts
├── astro.config.mjs
├── package.json
└── tsconfig.json
```

Starlight’s `docs` collection is patched by the platform package to resolve to `src/content/knowledge/`. That keeps `src/content/knowledge/` as the only real project-owned corpus while the public knowledge namespace continues to render at `/knowledge/...`.

The tenant manifest owns the package-facing path and feature contract. Site identity, branding, links, menus, and model defaults live in `src/config.yaml`. Package-owned routes and runtime code consume those boundaries instead of living in the project tree.

Static assets, including tenant branding assets, belong in the `public/` directory. Reference them from content or config with public paths such as `/logo.png`.

## 🧞 Commands

All commands below assume your shell is inside `docs/`:

| Command                   | Action                                           |
| :------------------------ | :----------------------------------------------- |
| `npm install`             | Installs dependencies                            |
| `npm run dev`             | Starts the unified local Wrangler runtime with MailPit, D1, KV, and generated books |
| `npm run dev:watch`       | Starts the same Wrangler runtime plus opt-in rebuild and browser refresh for core development |
| `npm run build`           | Build your production site to `./dist/`          |
| `npm run deploy`          | Provision or reuse Cloudflare resources and deploy the site |
| `npm run destroy`         | Dangerously delete the deployed site Worker, D1, and KV resources after typed confirmation |
| `npm run preview`         | Preview your build locally, before deploying     |
| `npm run astro ...`       | Run CLI commands like `astro add`, `astro check` |
| `npm run astro -- --help` | Get help using the Astro CLI                     |

## Build

Run docs commands directly from `docs/`:

| Command | Action |
| :------ | :----- |
| `npm install` | Install docs dependencies |
| `npm run dev` | Start the docs site through the unified local Wrangler runtime |
| `npm run dev:watch` | Start the same runtime with opt-in rebuild and browser refresh support |
| `npm run check` | Sync Astro/content state through the package-owned check flow |
| `npm run build` | Build the static docs output |
| `npm run deploy` | Run the package-owned Cloudflare deploy flow |
| `npm run destroy` | Run the package-owned Cloudflare destroy flow with typed confirmation |
| `npm run test` | Run unit tests plus Cloudflare-local integration coverage |
| `npm run cleanup:markdown -- <path>` | Normalize Markdown/MDX files before publishing |

The optional aggregated markdown books can be regenerated with `node ./node_modules/@treeseed/core/dist/scripts/aggregate-book.js`. They are build outputs and should not be committed.

If you still need the nested monorepo wrappers before the split, the runtime repo currently exposes `npm run docs:*` aliases from its top-level `package.json`. Do not treat those wrappers as the long-term interface.

## Package Release

`@treeseed/core` now lives in `packages/core/` and is set up to publish as a public npm package.

To scaffold a brand new tenant from the package:

```bash
npx treeseed init my-docs-site --name "My Docs Site" --site-url https://example.com
```

Release workflow:

1. update [packages/core/package.json](/home/adrian/Projects/nexical/karyon/docs/packages/core/package.json) with the target version
2. create a matching git tag in the form `treeseed-core-v<version>`
3. push the tag or run the publish workflow manually

Examples:

```bash
cd docs/packages/core
npm run release:check-tag -- treeseed-core-v0.1.0
npm run release:verify
git tag treeseed-core-v0.1.0
git push origin treeseed-core-v0.1.0
```

The publish workflow validates that the tag version exactly matches `packages/core/package.json` before publishing to npm, and it now executes the package-local release scripts from `packages/core/`.

## Markdown Authoring

The docs site is optimized for plain Markdown authoring. Prefer `.md` for most content and only reach for `.mdx` when the page genuinely needs a custom component.

### Math

- Use inline math for short symbols and expressions such as `$\\mathcal{O}(L \\times I)$`.
- Use display math for derivations or multi-term expressions:

```md
$$
E_t = \\frac{1}{2} \\sum_{l=1}^L \\|\\mathbf{x}_t^l - \\mu_t^l\\|_{\\Sigma_t^l}^2
$$
```

- Prefer one formula per display block when the notation is dense.
- Follow each formula with a plain-language sentence explaining the variables and why the expression matters.
- Avoid unnecessary escaping beyond what Markdown requires.

### Code Blocks

- Always include a language on fenced code blocks such as `bash`, `elixir`, `rust`, `yaml`, or `text`.
- Add a short sentence before long code blocks so readers know what they are looking at.
- Prefer smaller, focused examples over large uninterrupted dumps.
- Use inline code for short commands, filenames, symbols, and config keys only.

### Readability Patterns

- For research-heavy pages, prefer an “equation then explanation” rhythm.
- If a formula introduces several symbols, add a short bullet list or table immediately after it.
- Reserve MDX-only enhancements for cases that truly need interactivity or bespoke layout.

## Markdown Cleanup

AI-exported reports often arrive with broken paragraph spacing, malformed list boundaries, or inconsistent code-fence separation. The docs workspace includes a conservative cleanup tool to normalize those files before publication.

Use it as an explicit import step:

1. export the report to `.md` or `.mdx`
2. run Markdown cleanup
3. review the normalized output
4. publish the file into the docs/content tree

Commands:

| Command | Action |
| :------ | :----- |
| `npm run cleanup:markdown -- <path>` | Normalize one file, many files, or a directory tree in place |
| `npm run cleanup:markdown:check -- <path>` | Check whether files need cleanup without rewriting them |

Defaults and guarantees:

- if no path is provided, the cleanup tool scans the public docs content roots
- only `.md` and `.mdx` files are processed
- the tool is designed for safe normalization, not editorial rewriting
- it preserves frontmatter, math, reference anchors, Markdown links, and MDX components
- normal docs builds do not mutate source content automatically

## Local Form Development

The docs site owns its local email testing workflow through the `treeseed` CLI.

- MailPit is package-managed by `@treeseed/core`; the tenant no longer carries a `compose.yml`
- `.env.local` is the canonical local config file for the docs site
- every docs-site environment variable is prefixed with `DOCS_`

### Cloudflare-local mode

Run from inside `docs/`:

| Command | Action |
| :------ | :----- |
| `npm run dev` | Starts MailPit, syncs local env into Wrangler, runs local D1 migration, builds the site, and launches `wrangler dev --local` |
| `npm run dev:watch` | Runs the same Cloudflare-local stack, plus an opt-in rebuild and browser refresh loop for core development |

Behavior:

- MailPit listens on `127.0.0.1:1025`
- the MailPit inbox UI is available at `http://127.0.0.1:8025`
- local KV and D1 bindings come from `wrangler.toml`
- local Wrangler vars are generated from `.env.local` into `.dev.vars`
- `DOCS_LOCAL_DEV_MODE=cloudflare` is the only supported local runtime mode
- `npm run dev:watch` keeps Wrangler as the only runtime host; it simply rebuilds the app and refreshes the browser after supported file changes
- bypass flags such as `DOCS_FORMS_LOCAL_BYPASS_TURNSTILE` stay explicit, so local Cloudflare runs are production-like unless you opt into local shortcuts

## Local Test Parity

`npm run test` validates both the fast unit-test layer and a Cloudflare-local integration flow.

Behavior:

- integration coverage boots the Worker with `wrangler dev --local`
- the harness runs the local D1 migration before issuing test requests
- form token issuance, submission redirects, subscriber writes, nonce replay rejection, and rate limiting are exercised through HTTP against the local Worker
- test-specific env overrides are written through `.dev.vars` so the Worker sees the same style of bindings and secrets as local development

## Split Readiness

The future standalone docs repository should own these deployment and runtime inputs:

- GitHub Actions workflow at `.github/workflows/deploy.yml`
- deploy manifest at `treeseed.site.yaml`
- docs-local runtime variables defined in `.env.local.example`
- SQL migrations in `migrations/`
- generated deployment state under `.treeseed/` as runtime artifacts, not committed source

The package now generates Wrangler deploy config into `.treeseed/generated/wrangler.toml`, so the tenant no longer treats a hand-authored root `wrangler.toml` as the source of truth.

### Troubleshooting

- If Docker is not running, `npm run dev` and `npm run test` will fail early with a MailPit setup message.
- If `.env.local` is missing, copy `.env.local.example` into place.
- If local form emails do not appear, check `http://127.0.0.1:8025` and then `npm run mailpit:logs`.
- If Cloudflare-local startup fails on bindings, rerun `npm run sync:devvars` and `npm run d1:migrate:local`.
