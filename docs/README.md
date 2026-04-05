# Karyon Docs Tenant

This directory is a Treeseed tenant site for Karyon.

Treat it as if it were its own repository that installs `@treeseed/core` from npm. The current `file:packages/core` dependency is only a temporary monorepo convenience while the platform package and the Karyon tenant continue to evolve together.

## What Lives Here

This tenant should contain project payload and deployment configuration, not framework internals.

Source-of-truth tenant files:

- `treeseed.site.yaml`: deploy-time site contract for Treeseed and Cloudflare
- `src/config.yaml`: site identity, branding, navigation, and public-facing configuration
- `src/manifest.yaml`: content and feature contract consumed by `@treeseed/core`
- `src/content/**`: tenant-owned content
- `src/agents/*.ts`: tenant-owned agent implementations
- `public/`: static public assets such as logos, images, and downloads
- `astro.config.mjs`: thin package-mounted Astro entrypoint
- `src/content.config.ts`: thin package-mounted content collections entrypoint
- `src/env.d.ts`: tenant-side type surface for the local app
- `migrations/`: tenant-owned D1 schema migrations
- `.env.local`: local development configuration

Generated artifacts that are not source:

- `.treeseed/`: generated Wrangler config, deploy state, worker build output
- `public/books/*.md`: generated book exports
- `dist/`: static site build output
- `.dev.vars`: generated local Wrangler env file

## Runtime Model

The production architecture is:

- a fully static Astro site
- a very small Cloudflare Worker for `/api/*`
- one D1 database per site
- two KV namespaces per site

For Karyon, the generated D1 database name is now `karyon-docs-site-data`, which better reflects that it stores more than subscriber records.

Treeseed keeps the Worker small enough for Cloudflare's free tier by reserving it for runtime concerns only:

- form token issuance
- form submission
- nonce and rate-limit protection
- session and guard state
- optional SMTP and Turnstile integration

Regular site pages, content routes, books, feed output, and static assets are prerendered.

## Local Development

Run all tenant commands from inside `docs/`:

```bash
cd docs
npm install
```

Even though this repo currently points to `file:packages/core`, the intended consumer workflow is the same as an npm-installed tenant.

Main commands:

| Command | Action |
| :------ | :----- |
| `npm run dev` | Start the unified local Treeseed environment: static site, tiny Worker, Mailpit, local D1/KV, and generated books |
| `npm run dev:watch` | Start the same environment with rebuilds and browser refresh for active core development |
| `npm run build` | Build the static site and generated Worker artifacts |
| `npm run check` | Run the package-owned validation flow for the tenant |
| `npm run deploy` | Provision or reuse Cloudflare resources and deploy the site |
| `npm run destroy` | Dangerously delete the site's Worker, D1 database, and KV namespaces after typed confirmation |
| `npm run preview` | Preview the built site locally |
| `npm run cleanup:markdown -- <path>` | Normalize Markdown/MDX files |
| `npm run test` | Run tenant-facing unit and integration checks through Treeseed |

Additional local helpers:

| Command | Action |
| :------ | :----- |
| `npm run mailpit:up` | Start the package-managed Mailpit service |
| `npm run mailpit:down` | Stop the package-managed Mailpit service |
| `npm run mailpit:logs` | View Mailpit logs |
| `npm run sync:devvars` | Regenerate `.dev.vars` from local env |
| `npm run d1:migrate:local` | Apply local D1 migrations |
| `npm run astro -- --help` | Pass through to the package-owned Astro CLI wrapper |

## Local Environment

Treeseed owns the local runtime contract.

Local development uses:

- Mailpit on `127.0.0.1:1025`
- Mailpit UI on `http://127.0.0.1:8025`
- local D1 and KV bindings through generated Wrangler config
- `.env.local` as the canonical local environment file
- `.dev.vars` as the generated Wrangler-local env file

Important notes:

- local bypass flags such as `TREESEED_FORMS_LOCAL_BYPASS_TURNSTILE` are for local development only
- production builds explicitly clear local-only bypass flags
- the tenant no longer owns a `compose.yml`; Mailpit is managed by the package CLI

## Deployment

Treeseed deploys this site with a single command:

```bash
npm run deploy
```

That flow:

1. reads `treeseed.site.yaml`
2. reconciles Cloudflare resources
3. generates `.treeseed/generated/wrangler.toml`
4. syncs secrets and vars
5. applies remote D1 migrations
6. builds the static site and tiny Worker
7. publishes the Worker plus static assets

Use a dry run first when changing deploy behavior:

```bash
npm run deploy -- --dry-run
```

The GitHub Actions workflow at [deploy.yml](/home/adrian/Projects/nexical/karyon/docs/.github/workflows/deploy.yml) now uses that same `npm run deploy` path from `docs/`, so CI deploys the same Cloudflare Worker, D1 database, KV namespaces, generated Wrangler config, and static assets as local deploys.

For automated deploys, keep these secrets in GitHub Actions:

- `CLOUDFLARE_API_TOKEN`
- `TREESEED_FORM_TOKEN_SECRET`
- `TREESEED_PUBLIC_TURNSTILE_SITE_KEY`
- `TREESEED_TURNSTILE_SECRET_KEY`
- SMTP secrets when SMTP is enabled

Treeseed deploy now treats Turnstile as part of the standard production contract, so production deploys should always provide the public site key and the secret key.

Generated deployment state is written to:

- `.treeseed/generated/wrangler.toml`
- `.treeseed/state/deploy.json`

Those files are operational artifacts and should not be committed.

## Destroying a Site

`npm run destroy` is intentionally dangerous.

It deletes the site's:

- Cloudflare Worker
- D1 database
- KV namespaces

By default it prints the resources it is about to remove and requires typed confirmation matching the site slug from `treeseed.site.yaml`.

Use a dry run first:

```bash
npm run destroy -- --dry-run
```

## Content and Books

Treeseed patches the Starlight docs collection so tenant knowledge content lives in:

- `src/content/knowledge/`

Generated book exports are written to `public/books/` during build and development, but they are build artifacts and should not be committed.

Static assets should live in `public/` and be referenced by public paths such as `/logo.png`.

## Markdown Authoring

Prefer `.md` unless a page genuinely needs MDX components.

Authoring guidelines:

- use fenced code blocks with a language
- explain equations in plain language after displaying them
- keep long examples focused and contextualized
- use MDX only when a custom component materially improves the page

Markdown cleanup helpers are available through:

- `npm run cleanup:markdown -- <path>`
- `npm run cleanup:markdown:check -- <path>`

## Working On This Tenant As A Future Standalone Repo

The intended steady-state boundary is:

- tenant repo installs `@treeseed/core` from npm
- tenant repo carries only payload, deploy config, migrations, and thin Astro entrypoints
- Treeseed owns the runtime, CLI, build pipeline, deploy pipeline, forms runtime, and Worker implementation

Because this package is still temporarily developed in the same repository, you will see local paths like `packages/core/`. Treat those as contributor-only details, not part of the long-term tenant contract.

## Troubleshooting

- If Docker is not running, `npm run dev` and `npm run test` will fail when Mailpit cannot start.
- If `.env.local` is missing, copy `.env.local.example` into place.
- If local form email does not appear, open `http://127.0.0.1:8025` and then run `npm run mailpit:logs`.
- If local Cloudflare bindings drift, rerun `npm run sync:devvars` and `npm run d1:migrate:local`.
- If a deploy looks wrong, inspect `.treeseed/generated/wrangler.toml` and rerun `npm run deploy -- --dry-run`.
