# Karyon Docs

This site contains the architecture book and operator-facing documentation for Karyon.

## Current State

The docs describe both the target organism and the codebase that exists today. Treat the codebase as the source of truth for runtime behavior:

- the docs book is maintained in `src/content/docs/`
- the public site now combines editorial pages in `src/pages/` with Starlight docs under `src/content/docs/docs/`
- `public/books/*.md` are generated book exports, not guaranteed checked-in artifacts
- production-facing integrations such as XTDB, NATS, and Firecracker are still being hardened
- use the root `PLAN.md` and `TASKS.md` to track readiness work

## 🚀 Project Structure

Inside of your Astro + Starlight project, you'll see the following folders and files:

```
.
├── public/
├── src/
│   ├── assets/
│   ├── components/
│   ├── content/
│   │   ├── docs/
│   │   ├── notes/
│   │   └── pages/
│   ├── layouts/
│   ├── pages/
│   ├── styles/
│   └── utils/
│   └── content.config.ts
├── astro.config.mjs
├── package.json
└── tsconfig.json
```

Starlight looks for `.md` or `.mdx` files in the `src/content/docs/` directory. The public docs namespace now lives under `src/content/docs/docs/`, which renders at `/docs/...`.

Images can be added to `src/assets/` and embedded in Markdown with a relative link.

Static assets, like favicons, can be placed in the `public/` directory.

## 🧞 Commands

All commands are run from the root of the project, from a terminal:

| Command                   | Action                                           |
| :------------------------ | :----------------------------------------------- |
| `npm install`             | Installs dependencies                            |
| `npm run dev`             | Starts local dev server at `localhost:4321`      |
| `npm run build`           | Build your production site to `./dist/`          |
| `npm run preview`         | Preview your build locally, before deploying     |
| `npm run astro ...`       | Run CLI commands like `astro add`, `astro check` |
| `npm run astro -- --help` | Get help using the Astro CLI                     |

## Build

Run docs commands from the repo root via the workspace scripts, or from `docs/` directly if you prefer:

| Command | Action |
| :------ | :----- |
| `npm install` | Install workspace dependencies from the repo root |
| `npm run docs:dev` | Start the docs site locally |
| `npm run docs:dev:cloudflare` | Start the docs site through Wrangler with local Cloudflare bindings |
| `npm run docs:check` | Run Astro type/content checks |
| `npm run docs:build` | Build the static docs output |
| `npm run docs:normalize -- <path>` | Normalize Markdown/MDX files before publishing |

The optional aggregated markdown books can be produced with `node scripts/aggregate-book.mjs`.

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
| `npm run cleanup:markdown --workspace docs -- <path>` | Normalize one file, many files, or a directory tree in place |
| `npm run cleanup:markdown:check --workspace docs -- <path>` | Check whether files need cleanup without rewriting them |

Defaults and guarantees:

- if no path is provided, the cleanup tool scans the public docs content roots
- only `.md` and `.mdx` files are processed
- the tool is designed for safe normalization, not editorial rewriting
- it preserves frontmatter, math, reference anchors, Markdown links, and MDX components
- normal docs builds do not mutate source content automatically

## Local Form Development

The docs site now owns its local email testing workflow inside `docs/`.

- `docs/compose.yml` runs a MailPit SMTP server and inbox UI for form testing
- `docs/.env.local` is the canonical local config file for the docs site
- every docs-site environment variable is prefixed with `DOCS_`

### Astro-local mode

Run from the repo root:

| Command | Action |
| :------ | :----- |
| `npm run docs:dev` | Starts MailPit, then runs plain `astro dev` |

Behavior:

- MailPit listens on `127.0.0.1:1025`
- the MailPit inbox UI is available at `http://127.0.0.1:8025`
- Turnstile is bypassed by default for local testing
- Cloudflare-only guard/subscriber dependencies fall back to local adapters

### Cloudflare-local mode

Run from the repo root:

| Command | Action |
| :------ | :----- |
| `npm run docs:dev:cloudflare` | Starts MailPit, syncs local env into Wrangler, runs local D1 migration, builds the site, and launches `wrangler dev` |

Behavior:

- local KV and D1 bindings come from `docs/wrangler.toml`
- local Wrangler vars are generated from `docs/.env.local` into `docs/.dev.vars`
- set `DOCS_LOCAL_DEV_MODE=cloudflare` plus the bypass flags you want for local testing

### Troubleshooting

- If Docker is not running, `npm run docs:dev` and `npm run docs:dev:cloudflare` will fail early with a MailPit setup message.
- If `docs/.env.local` is missing, copy `docs/.env.local.example` into place.
- If local form emails do not appear, check `http://127.0.0.1:8025` and then `npm run mailpit:logs --workspace docs`.
- If Cloudflare-local startup fails on bindings, rerun `npm run sync:devvars --workspace docs` and `npm run d1:migrate:local --workspace docs`.
