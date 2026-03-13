# Karyon AI Application Platform

Karyon is a structurally discrete, biomimetic multi-agent ecosystem. It explicitly abandons standard monolithic, autoregressive, and stateless deep learning paradigms in favor of a "Biological Intelligence" approach—emphasizing concurrent, self-organizing, localized cells over centralized dense matrix computations.

## Architecture

*   **The Karyon (Nucleus):** Immutable Elixir/Rust core microkernel.
*   **The Cytoplasm:** Erlang VM (BEAM) for massive concurrency.
*   **The Rhizome (Memory):** Bitemporal, graph-based knowledge layer (XTDB / Memgraph).
*   **Organelles:** Optimized Rust NIFs for heavy computation.
*   **DNA:** Declarative YAML schemas defining agent bounds.

For more details, see [SPEC.md](SPEC.md) and [docs/public/book.md](docs/public/book.md).

## Getting Started

The easiest way to run the Karyon organism is using `make`. This ensures all backing services are started before the Elixir Nucleus initializes.

### Prerequisites

*   **Elixir** 1.15+
*   **Erlang/OTP** 26+
*   **Docker & Docker Compose** (for backing services)
*   **Rust** (for future NIF organelles)

## Operations & Documentation

- [Genetic Blueprint Guide](file:///home/adrian/Projects/nexical/karyon/docs/OPERATIONS/GENETICS.md) — How to author cellular DNA.
- [Metabolic Operations Playbook](file:///home/adrian/Projects/nexical/karyon/docs/OPERATIONS/METABOLICS.md) — Monitoring, health, and apoptosis debugging.
- [Developer & NIF Safety](file:///home/adrian/Projects/nexical/karyon/docs/DEVELOPER/NIF_SAFETY.md) — FFI architecture and native extension guide.
- [Project Walkthrough](file:///home/adrian/.gemini/antigravity/brain/66d06a40-b9b4-4d78-8e5d-47e5f6398975/walkthrough.md) — Technical implementation summary.

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
