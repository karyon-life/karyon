# Karyon AI Application Platform

Karyon is a structurally discrete, biomimetic multi-agent ecosystem. It explicitly abandons standard monolithic, autoregressive, and stateless deep learning paradigms in favor of a "Biological Intelligence" approach—emphasizing concurrent, self-organizing, localized cells over centralized dense matrix computations.

## Architecture

*   **The Karyon (Nucleus):** Immutable Elixir/Rust core microkernel.
*   **The Cytoplasm:** Erlang VM (BEAM) for massive concurrency.
*   **The Rhizome (Memory):** Bitemporal, graph-based knowledge layer (XTDB / Memgraph).
*   **Organelles:** Optimized Rust NIFs for heavy computation.
*   **DNA:** Declarative YAML schemas defining agent bounds.

For more details, see [SPEC.md](SPEC.md) and [docs/public/book.md](docs/public/book.md).

## Prerequisites

*   **Elixir** 1.15+
*   **Erlang/OTP** 26+
*   **Rust** (for NIFs)
*   **Memgraph / XTDB** (for the Rhizome)

## Getting Started

To run the application in an interactive Elixir shell (IEx):

```bash
./bin/run
```

To run the application in non-interactive (server) mode:

```bash
./bin/run --server
```

This will:
1.  Check for necessary dependencies.
2.  Compile the Elixir and Rust components.
3.  Start the umbrella application using `mix run --no-halt`.

## Development

See [PLAN.md](PLAN.md) for the development roadmap and current progress.
See [GEMINI.md](GEMINI.md) for AI-specific development guidelines.
