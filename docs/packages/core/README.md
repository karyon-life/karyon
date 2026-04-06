# @treeseed/core

`@treeseed/core` is the Treeseed platform package for content-driven sites deployed as:

- a static Astro site
- a tiny Cloudflare Worker for runtime API concerns
- one D1 database per site
- two KV namespaces per site

The package is designed to be installed from npm by downstream tenant repositories. Its current location inside this monorepo is temporary and exists only so the Karyon tenant and the package can be developed together while the platform stabilizes.

## What The Package Owns

`@treeseed/core` is intended to own nearly all framework and runtime behavior for a tenant site:

- Astro and Starlight integration
- shared layouts, components, routes, and styles
- forms runtime and Cloudflare Worker implementation
- local dev and package CLI commands
- Cloudflare deploy and destroy flows
- generated book exports
- agent runtime framework, contracts, and shared helpers
- tenant scaffolding through `treeseed init`

A tenant repository should mainly keep:

- `treeseed.site.yaml`
- `src/config.yaml`
- `src/manifest.yaml`
- `src/content/**`
- `src/agents/*.ts`
- `public/`
- `src/env.d.ts`
- `migrations/`
- thin `astro.config.mjs` and `src/content.config.ts` wrappers

## Installation

In a normal consumer repository:

```bash
npm install @treeseed/core
```

A typical tenant `package.json` is expected to expose Treeseed through scripts like:

```json
{
  "scripts": {
    "dev": "treeseed dev",
    "dev:watch": "treeseed dev --watch",
    "build": "treeseed build",
    "check": "treeseed check",
    "deploy": "treeseed deploy",
    "destroy": "treeseed destroy",
    "preview": "treeseed preview"
  }
}
```

Inside this monorepo, contributors develop through the npm workspace rooted at `docs/`. The Karyon tenant resolves `@treeseed/core` locally through workspace linking, but downstream consumers are still expected to install from npm.

## Tenant CLI

Installed tenants use the `treeseed` CLI.

Core commands:

- `treeseed dev`
- `treeseed dev --watch`
- `treeseed build`
- `treeseed check`
- `treeseed preview`
- `treeseed deploy`
- `treeseed destroy`
- `treeseed init <directory>`

Additional helpers:

- `treeseed mailpit:up`
- `treeseed mailpit:down`
- `treeseed mailpit:logs`
- `treeseed sync:devvars`
- `treeseed d1:migrate:local`
- `treeseed cleanup:markdown`
- `treeseed cleanup:markdown:check`
- `treeseed test:unit`
- `treeseed test:integration`
- `treeseed test:e2e`
- `treeseed test`
- `treeseed agents`

`treeseed destroy` is intentionally dangerous. By default it prints the Worker, D1, and KV resources it is about to delete and requires typed confirmation matching the tenant slug.

## Deploy Model

Treeseed deploys one isolated site at a time.

Per site, the package provisions or reconciles:

- one Cloudflare Worker
- one D1 database
- one `FORM_GUARD_KV` namespace
- one `SESSION` namespace

For the Karyon tenant, the D1 database name is now `karyon-docs-site-data`, reflecting that the database stores broader site data rather than only subscribers.

Deployment inputs are read from `treeseed.site.yaml` and tenant config files. The package generates operational artifacts such as:

- `.treeseed/generated/wrangler.toml`
- `.treeseed/state/deploy.json`
- `.treeseed/generated/worker/`

These are runtime artifacts, not source files.

A tenant CI workflow should call `npm run deploy` from the tenant root so automated deploys use the same Treeseed provisioning and publish path as local deploys. Avoid separate `wrangler pages deploy` or ad hoc Worker publish steps that bypass the generated Treeseed deploy contract.

## Plugin System

Treeseed now uses an explicit plugin system configured in `treeseed.site.yaml`.

Each tenant declares:

- `plugins`: an ordered list of plugin packages to load
- `providers`: the selected implementation id for each singular extension point

Treeseed loads plugins in declaration order, validates that each selected provider id exists, and then routes site build, forms runtime, worker runtime, agent runtime, and deploy behavior through the resolved plugin runtime.

Typical config:

```yaml
plugins:
  - package: '@treeseed/core/plugin-default'
providers:
  forms: store_only
  agents:
    execution: stub
    mutation: local_branch
    repository: stub
    verification: stub
    notification: stub
    research: stub
  deploy: cloudflare
  content:
    docs: default
  site: default
```

### Built-In Plugin

Treeseed currently ships one built-in first-party plugin:

- `@treeseed/core/plugin-default`

This plugin declares the built-in provider ids and handler ids that make the default Treeseed platform work out of the box. Tenants should usually keep this plugin in their `plugins` list unless they are replacing the entire default platform surface.

### Built-In Provider Ids

Forms providers:

- `store_only`
- `notify_admin`
- `full_email`

Agent providers:

- `agents.execution`: `stub`, `manual`, `copilot`
- `agents.mutation`: `local_branch`
- `agents.repository`: `stub`, `git`
- `agents.verification`: `stub`, `local`
- `agents.notification`: `stub`
- `agents.research`: `stub`

Other providers:

- `deploy`: `cloudflare`
- `content.docs`: `default`
- `site`: `default`

### Default Provider Behavior

Forms:

- `store_only`: persists contact and subscriber data, enforces guards and Turnstile, and sends no email
- `notify_admin`: keeps the same persistence path and sends admin notifications when SMTP is available
- `full_email`: requires SMTP, sends admin notifications, and also sends the built-in subscriber confirmation email

Agents:

- `stub` execution: returns a synthetic completed result without calling an external tool
- `manual` execution: emits a manual handoff payload for operator-driven execution
- `copilot` execution: invokes `gh copilot` with the normalized agent CLI options
- `local_branch` mutation: writes artifacts into a git worktree/branch and commits them
- `stub` repository inspection: returns a no-op branch inspection result
- `git` repository inspection: inspects changed paths and HEAD sha from the local repo
- `stub` verification: reports success without running commands
- `local` verification: runs configured verification commands via `/bin/bash -lc`
- `stub` notification: records prepared notifications without delivering them externally
- `stub` research: returns placeholder research markdown

Content and site:

- `content.docs: default`: uses the Starlight docs loader and schema, keeps Treeseed’s generated knowledge doc ids, and extends docs entries with default tags
- `site: default`: keeps the built-in routes, Starlight component overrides, theme injection, markdown plugins, env schema, and route middleware
- `deploy: cloudflare`: keeps the current Cloudflare worker, D1, KV, generated Wrangler config, and worker artifact flow

### Extension Points

Plugin authors can now extend or replace these seams:

- forms provider selection through `providers.forms`
- agent adapter providers through `providers.agents.*`
- agent handler registration through plugin-contributed handler ids
- site provider selection through `providers.site`
- additive site hooks for routes, Starlight component overrides, custom CSS, markdown plugins, env schema additions, Vite plugins, integrations, and route middleware
- docs content provider selection through `providers.content.docs`

In practical terms, the current runtime seams are:

- forms runtime collaborators: guard store, subscriber store, contact store, email delivery, Turnstile verification, and provider-specific behavior
- agent runtime collaborators: execution, mutation, repository inspection, verification, notification, research, and agent handlers
- Astro site composition: routes, integrations, component overrides, markdown hooks, theme/css injection, env schema, and middleware
- content composition: docs loader/schema resolution
- deploy/runtime selection: the selected deploy provider id carried through deploy generation

### Plugin Authoring Contract

Core exports:

- `defineTreeseedPlugin`
- `loadTreeseedPlugins`
- `loadTreeseedPluginRuntime`

Third-party plugins may contribute:

- metadata describing which provider ids they supply
- `formsProviders`
- `agentProviders`
- `agentHandlers`
- `siteProviders`
- `siteHooks`
- `contentProviders`

Treeseed treats singular providers and additive hooks differently:

- singular providers are selected by id through `providers`
- additive hooks are composed in plugin declaration order

Duplicate contributed provider ids are treated as startup errors. Unknown selected provider ids are also startup errors.

## Forms Runtime

Forms behavior now comes from the selected `providers.forms` plugin implementation in `treeseed.site.yaml`.

The built-in forms provider ids are:

- `store_only`
- `notify_admin`
- `full_email`

This keeps the default platform affordable and usable without SMTP, while still allowing richer behavior when a tenant explicitly selects a richer provider.

Turnstile is part of the standard production deploy contract. Treeseed deploy expects `TREESEED_PUBLIC_TURNSTILE_SITE_KEY` and `TREESEED_TURNSTILE_SECRET_KEY` to be provided for production publishes.

## Agent Runtime

Agent execution behavior now comes from `providers.agents.execution` in `treeseed.site.yaml`.

The built-in execution provider ids are:

- `stub`
- `manual`
- `copilot`

This keeps new sites usable without paid AI execution tooling and lets tenants opt into more capable execution providers later.

## Local Development Model

Treeseed keeps a unified local environment:

- static site build output
- tiny Worker runtime for `/api/*`
- Mailpit for local email testing
- local D1 and KV bindings
- generated book exports

`treeseed dev` starts the normal unified local environment.

`treeseed dev --watch` keeps the same runtime model but adds rebuild and browser refresh support for active package development.

Mailpit is package-managed. Tenant repositories do not need their own `compose.yml`.

## Scaffolded Tenant Contract

`treeseed init` scaffolds a new tenant with the package-first contract.

Expected tenant-owned structure:

- `treeseed.site.yaml`
- `src/config.yaml`
- `src/manifest.yaml`
- `src/content/**`
- `src/agents/*.ts`
- `public/`
- `migrations/`
- `astro.config.mjs`
- `src/content.config.ts`
- `src/env.d.ts`

Generated books under `public/books/*.md` are build artifacts and should not be committed.

Tenant branding assets should live in `public/` and be referenced through public paths and `src/config.yaml`.

## Package Development In This Repository

While the package still lives here, the preferred contributor entrypoint is the workspace root at `docs/`.

Use the workspace root when you need layered development or release verification:

- `npm install`
- `npm run dev`
- `npm run dev:watch`
- `npm run test:unit`
- `npm run test:release`
- `npm run release:publish:changed`

Run package-local commands from `docs/packages/core/` when you need to focus on `core` in isolation.

Useful commands:

- `npm run build:dist`: build the published `dist/` package output
- `npm run check`: validate the internal fixture app
- `npm run build`: build the internal fixture app
- `npm run dev`: run the internal fixture dev environment
- `npm run dev:watch`: run the same fixture with rebuild and refresh support
- `npm run test:unit`: fast package-level tests
- `npm run test:integration`: Cloudflare-local integration tests
- `npm run test:e2e`: package-owned end-to-end coverage
- `npm run test:scaffold`: scaffold smoke test
- `npm run release:verify`: package-local release verification flow before publishing

The workspace root also offers two release-smoke levels:

- `npm run test:release`: faster tarball smoke for local iteration
- `npm run test:release:full`: full tarball smoke including scaffold deploy dry-run

When `@treeseed/sdk` changes, the workspace dev loop rebuilds `sdk`, then `core`, then the tenant runtime so local testing stays close to hot reload without publishing intermediate artifacts.

The fixture app under `fixture/` exists only for package development and verification. It is not part of the downstream tenant contract.

## Publishing

The package publishes built artifacts from `dist/`.

Release flow:

1. update the package version in `package.json`
2. run `npm run release:verify`
3. create a matching git tag: `treeseed-core-v<version>`
4. publish through the release workflow or `npm run release:publish`

This package uses a `files` whitelist and generated `dist/` exports so downstream consumers do not depend on the raw source tree.

## Temporary Monorepo Context

A few repository details in this workspace are temporary and should not be treated as part of the long-term public interface:

- the package source currently lives under `docs/packages/core/`
- the Karyon tenant currently resolves the package through the local npm workspace during contributor development
- fixture and workspace scripts exist to help package development before extraction

The long-term contract is npm-first: tenants install `@treeseed/core` and interact with it through the `treeseed` CLI and exported entrypoints.
