# Karyon Docs

This site contains the architecture book and operator-facing documentation for Karyon.

## Current State

The docs describe both the target organism and the codebase that exists today. Treat the codebase as the source of truth for runtime behavior:

- the docs book is maintained in `src/content/docs/`
- `public/book.md` is optional generated output, not a guaranteed checked-in artifact
- production-facing integrations such as XTDB, NATS, and Firecracker are still being hardened
- use the root `PLAN.md` and `TASKS.md` to track readiness work

## 🚀 Project Structure

Inside of your Astro + Starlight project, you'll see the following folders and files:

```
.
├── public/
├── src/
│   ├── assets/
│   ├── content/
│   │   └── docs/
│   └── content.config.ts
├── astro.config.mjs
├── package.json
└── tsconfig.json
```

Starlight looks for `.md` or `.mdx` files in the `src/content/docs/` directory. Each file is exposed as a route based on its file name.

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

Run docs commands from `docs/`:

| Command | Action |
| :------ | :----- |
| `npm install` | Install docs dependencies |
| `npm run dev` | Start the docs site locally |
| `npm run build` | Build the static docs output |

The optional aggregated markdown book can be produced with `node scripts/aggregate-book.mjs`.
