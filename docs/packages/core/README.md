# @treeseed/core

Main package-first Treeseed platform for Astro, Starlight, forms, books, and agent runtime behavior.

This package is intended to own nearly all application code. A project repository should keep only tenant config, content, branding assets, prompts, deploy/runtime config, and thin local wrappers required for Astro entrypoints.

The package now publishes a built `dist/` runtime and a package CLI, so tenant sites can depend on `@treeseed/core` alone.

## Package Operations

Run these commands from `docs/packages/core/` while the package still lives inside the Karyon docs workspace.

### Setup and Development

- `npm run setup`: install docs workspace dependencies from the package entrypoint
- `npm run dev`: start the docs fixture app that mounts `@treeseed/core`
- `npm run check`: run Astro/content checks against the fixture app
- `npm run build`: build the fixture app
- `npm run test`: run the fixture app test suite
- `npm run build:dist`: build the published package output under `dist/`

### Tenant CLI

Installed tenants use the `treeseed` CLI:

- `treeseed dev`
- `treeseed build`
- `treeseed check`
- `treeseed preview`
- `treeseed init <directory>`

`treeseed init` scaffolds a new tenant from `templates/site/`.

### Release

- `npm run release:check-tag -- treeseed-core-v0.1.0`: validate that a release tag matches the package version
- `npm run release:verify`: run the package verification flow before publishing
- `npm run release:publish`: publish `@treeseed/core` to npm

The GitHub workflow at `docs/.github/workflows/publish-core.yml` now calls these package-local scripts directly, so release automation is driven from the package interface instead of the tenant app root.

## Extract Readiness

This package is now prepared for extraction into its own repository:

- runtime and script dependencies are declared in `package.json`
- published runtime code is emitted into `dist/`, while source remains in `src/`
- publish boundaries are controlled with the `files` whitelist and `.npmignore`
- release validation and publish commands live under `scripts/`
- the remaining extraction steps are documented in [EXTRACTION.md](/home/adrian/Projects/nexical/karyon/docs/packages/core/EXTRACTION.md)
