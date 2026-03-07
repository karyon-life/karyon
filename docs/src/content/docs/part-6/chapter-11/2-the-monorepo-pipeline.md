---
title: "The Monorepo Pipeline"
---

The architecture of Karyon is not a monolithic script; it is a hybrid organism relying on two vastly different technological ecosystems to function. Elixir (on the Erlang VM) provides the highly concurrent, biologically fault-tolerant "cytoplasm" that orchestrates 500k-cell communication, while Rust provides the bare-metal "organelles" capable of traversing a 512GB RAM temporal graph at maximum bandwidth without garbage collection pauses.

Maintaining these two halves requires a unified build process. If you split the Elixir orchestrator and the Rust graph engine into separate repositories, the artificial integration boundary will shatter development velocity and introduce severe runtime volatility. A change in the Rust memory schemas demands immediate, reciprocal changes in the Elixir message-routing logic. Versioning them separately actively invites segmentation faults and deadlocks. 

The Karyon organism must be built, managed, and compiled as a single entity: the monorepo.

## The Karyon Monorepo Structure

The objective is to physically structure the repository to respect the biological boundaries of the design. The environment is separated into the Cytoplasm (Elixir), the Organelles (Rust), Immutable Genetics (DNA/Objectives), and isolated execution bounds (Sandbox).

```text
karyon/
├── mix.exs                     # The Elixir build manifest and BEAM dependencies
├── config/                     # Boot configurations for the Erlang VM
│   ├── config.exs
│   └── runtime.exs             # Threadripper CPU pinning and memory limits
│
├── lib/                        # THE CYTOPLASM (Elixir Source Code)
│   ├── karyon.ex               # The Application initialization (BOOT)
│   ├── karyon/
│   │   ├── epigenetic/         # The Epigenetic Supervisor (Stem cell differentiation)
│   │   ├── cells/              # The biological logic for different cell types
│   │   │   ├── stem.ex         # The base, zero-state worker process
│   │   │   ├── motor.ex        # Execution logic and sandbox triggers
│   │   │   └── receptor.ex     # Event listeners and ZeroMQ entry points
│   │   ├── nervous_system/     # Signal routing (ZeroMQ IPC, NATS Pub/Sub)
│   │   └── daemons/            # Biological drives
│   │       ├── metabolic.ex    # CPU/RAM utility calculus and Apoptosis execution
│   │       └── simulation.ex   # The "Dream" engine and KVM microVM orchestration
│
├── native/                     # THE ORGANELLES (Rust Source Code)
│   └── rhizome_engine/         # The Rustler NIF crate
│       ├── Cargo.toml          # Rust dependencies (Tree-sitter, XTDB/Memgraph drivers)
│       ├── src/
│       │   ├── lib.rs          # The Bridge: Defines what Rust functions Elixir can call
│       │   ├── graph/          # Core memory topology
│       │   │   ├── memory.rs   # MVCC logic and Threadripper 8-channel optimization
│       │   │   └── temporal.rs # Archiving logic for writing states to XTDB
│       │   ├── perception/     # The deterministic parsers
│       │   │   └── ast.rs      # Tree-sitter ingestion logic
│       │   └── daemons/        # Heavy background computation
│       │       └── sleep.rs    # Louvain community detection and graph pruning
│
├── priv/                       # IMMUTABLE GENETICS (Static Assets)
│   ├── dna/                    # YAML manifests that define cell differentiation
│   │   ├── eye_parser.yml
│   │   ├── motor_compiler.yml
│   │   └── generic_stem.yml
│   └── objectives/             # The base Attractor States (Core Values)
│       └── sovereign_law.yml   # e.g., The air-gapped isolation mandate
│
├── sandbox/                    # VIRTIO-FS MOUNT TARGETS (The Environment)
│   └── test_projects/          # Air-gapped code testbeds
│
├── test/                       # THE LABORATORY
│   ├── karyon_test/            # Elixir unit tests (Message routing verification)
│   └── rhizome_test/           # Rust unit tests (Graph pointer verification)
│
└── Makefile                    # Orchestrates compiling Rust and Elixir symbiotically
```

## The Workspace vs. The Sterile Engine

A critical distinction in this architecture is the complete separation of the Karyon core (the *engine*) from the target projects it manages (the *workspaces*). Note what is intentionally absent from the repository: target codebases and execution states.

The Karyon repository is the engine. When enacted, it projects its presence into a target workspace (e.g., an Astro application repository). The active `.nexical/plan.yml` sequences and the localized `.nexical/history/` archives live exactly where the work occurs, completely outside the immutable `karyon/` core directory. This separation guarantees that a catastrophic sandbox compilation failure has zero chance of corrupting the system's core source genetics.

## The Engineering Reality: The Rustler Bridge

The most technically demanding vector in this monorepo is the `native/` boundary. The Elixir Cytoplasm communicates with the Rust Organelles through Native Implemented Functions (NIFs), specifically using the `Rustler` crate to create the FFI (Foreign Function Interface) bindings.

### The Pain of the Bridge

While `mix compile` inside the root directory orchestrates building both halves of the organism flawlessly, writing the bridge is unforgiving.

*   **Type Marshaling (The Friction Zone):** Data passing from the BEAM (Elixir) to Rust must be serialized, transferred, and decoded. Passing large data structures (like a massive 10,000-node AST graph representation) back and forth continuously creates tremendous serialization overhead, choking the memory buses.
*   **The Zero-Copy Rule in NIFs:** The core rule of the Karyon implementation is to construct the architecture such that data stays in Rust. When Elixir requests graph traversal, it passes a tiny reference pointer (a Resource Object), not the graph itself. Rust does the heavy lifting, mutates the 512GB structure in its raw memory, and returns a boolean or another small reference.
*   **Dirty Schedulers vs. The Panic Risk:** By default, Elixir expects a NIF call to return under 1 millisecond. If Rust takes 5 seconds to run Louvain clustering, the BEAM scheduler assumes the thread is dead and crashes the beam. Heavy Rust workloads *must* be flagged as `Dirty CPU` or `Dirty IO` jobs, telling the BEAM scheduler to move the execution thread completely out of the critical path to prevent locking up the messaging system.

Bootstrapping is about aligning these competing constraints—establishing a single unified build environment that allows two wildly different programming realities to act as one cohesive cellular network.
