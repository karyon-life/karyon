# Extraction Checklist

Use this checklist when moving `@treeseed/core` out of the Karyon monorepo into its own repository.

## Package Boundary

- Move `packages/core/` contents to the repository root.
- Keep the published package name as `@treeseed/core`.
- Preserve `README.md`, `package.json`, `src/`, `test/`, and `scripts/`.
- Preserve the publish workflow semantics from `docs/.github/workflows/publish-core.yml`.

## Dependency Setup

- Run `npm install` in the extracted repository root to generate a package-local lockfile.
- Verify `npm run check`, `npm run build`, and `npm run test`.
- Confirm `treeseed-agents` is still exposed through the package `bin` entry.

## Fixture App

Today the package lifecycle scripts delegate to the docs fixture workspace in `docs/`.

When extracted:

- replace `scripts/run-docs-workspace-command.mjs` with direct package-local commands
- promote the fixture app files into the new repository root
- update package scripts so `setup`, `check`, `build`, `test`, and `dev` run directly instead of delegating upward

## Release

- keep release tags in the form `treeseed-core-v<version>`
- keep `scripts/assert-release-tag-version.mjs`
- ensure `NPM_TOKEN` is configured in GitHub Actions secrets
- validate `npm run release:check-tag -- treeseed-core-v<version>` before publishing

## Publish Surface

- keep the `files` whitelist in `package.json`
- keep `.npmignore` exclusions for tests and workspace-only artifacts
- verify `npm pack --dry-run` only contains the package runtime, scripts, and docs intended for consumers
