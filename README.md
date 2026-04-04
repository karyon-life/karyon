# Karyon AI Application Platform

Karyon is a structurally discrete, biomimetic multi-agent ecosystem. It explicitly abandons standard monolithic, autoregressive, and stateless deep learning paradigms in favor of a "Biological Intelligence" approach—emphasizing concurrent, self-organizing, localized cells over centralized dense matrix computations.

## Architecture

*   **The Karyon (Nucleus):** Immutable Elixir/Rust core microkernel.
*   **The Cytoplasm:** Erlang VM (BEAM) for massive concurrency.
*   **The Rhizome (Memory):** Bitemporal, graph-based knowledge layer (XTDB / Memgraph).
*   **Organelles:** Optimized Rust NIFs for heavy computation.
*   **DNA:** Declarative YAML schemas defining agent bounds.

For more details, see [SPEC.md](SPEC.md), [PLAN.md](PLAN.md), and the canonical docs references below.

## Getting Started

The easiest way to run the Karyon organism is using `make`. This ensures all backing services are started before the Elixir Nucleus initializes.

### Prerequisites

*   **Elixir** 1.15+
*   **Erlang/OTP** 26+
*   **Docker & Docker Compose** (for backing services)
*   **Rust** (for future NIF organelles)

## Operations & Documentation

- Published docs URL: `https://docs.karyon.dev`
- Planned standalone docs repository: `https://github.com/nexical/karyon-docs`
- Treat published docs and the future standalone docs repo as canonical documentation locations after the split.
- Until the split happens, the nested `docs/` directory is a transitional copy of that future standalone docs repository.

## Current Status

Karyon is currently an honest scaffold rather than a production-ready organism. The umbrella apps, OTP supervision, Rust NIF boundaries, and core documentation structure are present, but several production claims in the architecture are still in progress:

- `core` and `rhizome` contracts are not yet fully aligned on structured query results.
- Memgraph, XTDB, NATS, and Firecracker paths still require service-backed validation before they can be treated as production behavior.
- The sandbox execution membrane is partially mocked outside explicitly configured test or mock environments.
- Dashboard and operator surfaces are being brought in line with real telemetry rather than aspirational values.

Use [PLAN.md](PLAN.md) and [TASKS.md](TASKS.md) as the execution source of truth for runtime readiness work. Use the published docs URL and the future standalone docs repo for documentation references instead of repo-relative `docs/...` paths.

### Quick Start

To bootstrap dependencies, start backing services, and drop into an interactive Elixir shell (IEx):

```bash
make run
```

To run in non-interactive (server) mode:

```bash
make run-server
```

Individual components can also be managed:
*   `make up`: Start backing services (Memgraph, XTDB)
*   `make down`: Stop backing services
*   `make build`: Compile the application
*   `make deps`: Fetch dependencies

## Performance and Metabolic Efficiency

Karyon is designed with "Hardware Sympathy" to maximize metabolic efficiency.

1.  **Native Nucleus**: The Elixir application runs natively on the host machine via `bin/run`. This ensures the BEAM scheduler has direct access to CPU topologies and thread affinity (`ERL_AFLAGS="+sbt tnnps"`), avoiding the overhead and jitter of containerized networking and process scheduling.
2.  **Containerized Rhizome**: Backing services (Memgraph, XTDB) are containerized for development consistency. In high-performance production environments, these may be moved to bare-metal or NUMA-aware instances as defined in [SPEC.md](SPEC.md).

## Development

See [PLAN.md](PLAN.md) for the development roadmap and current progress.
See [GEMINI.md](GEMINI.md) for AI-specific development guidelines.
