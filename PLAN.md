# SYSTEM DIRECTIVE: KARYON MASTER EXECUTION PLAN

**Role:** Lead Systems Architect & Project Manager
**Target Architecture:** Distributed Cellular State Machine
**Core Stack:** Erlang/OTP, Elixir, Rust (Rustler), Memgraph, XTDB, AWS Firecracker
**Execution Philosophy:** Lock-Free Concurrency, Continuous Active Inference, Bitemporal Decentralized Graph Memory, Biomimetic Apoptosis.

This master plan structures the technical roadmap for the `app/` directory of the Karyon platform. It enforces strict separation of engine mechanics (sterile execution) from semantic intelligence (graph learning).

---

## PHASE 0: MVP SCOPE & THE MINIMUM VIABLE ORGANISM
**Objective:** Before scaling to 500,000+ concurrent Actor processes, establish a deterministic "Hello World" proving sequence to validate the cellular mechanics, FFI boundaries, and Graph storage.
**Deliverables:**
1. **The Scaffold:** A minimal `app/` Umbrella with `apps/core` and `apps/rhizome`.
2. **The First Cell:** A single Elixir Stem Cell boots, reads a declarative `DNA.yml` config, and initializes a ZeroMQ listener.
3. **The First Organelle:** The cell invokes a Rustler NIF carrying `Tree-sitter` to deterministically parse a simple script into an AST.
4. **The First Memory:** The Rust NIF writes the AST structure to a local `Memgraph` (Tier-0) instance without blocking the BEAM scheduler.
5. **The First Apoptosis:** The test intentionally feeds corrupted YAML to the Stem Cell, confirming the OTP Supervisor intercepts the crash without dropping the Memgraph connection.

---

## PHASE 1: Ecosystem Scaffolding & Umbrella Mapping
**Objective:** Establish the precise directory structure, build chains, and structural constants required by `SPEC.md`.

### 1. The Umbrella Definition (`app/mix.exs`)
Initialize a distributed Elixir Umbrella project (`mix new app --umbrella`), establishing absolute isolation of domains at the compiler boundary, while permitting seamless deployment into a single unified BEAM instance.

### 2. Sub-Application Architecture
- `apps/core`: The **Microkernel** and **Cytoplasm**. Contains the `EpigeneticSupervisor` and the `gen_server` stem cell behavioral templates (Actors).
- `apps/nervous_system`: The **Synaptic** layer. Abstracted zero-copy routing architectures embedding `chumak` (ZeroMQ) and `tortoise` (NATS Core).
- `apps/rhizome`: The **Memory** and **Organelle** boundary. Contains database connection pooling (Memgraph/XTDB) and the Rust Native Implemented Functions (NIFs) housed in `apps/rhizome/native/`.
- `apps/sandbox`: The **Membrane**. Orchestrates the isolation bridging execution commands to AWS Firecracker microVMs over Virtio-fs socket bindings.

### 3. Integrated Build Chain
Draft the root `Makefile` to orchestrate parallel routines:
1. `cargo build --release` targeting library exports for `apps/rhizome/native/`.
2. `mix deps.get && mix compile`.
3. Bootstrapping `docker-compose` dependencies (Memgraph, XTDB) via strictly mapped bare-metal networking.

---

## PHASE 2: The Nervous System & Cytoplasm (Elixir/BEAM)
**Objective:** Orchestrate massive lock-free scale whilst mathematically avoiding process tracking "Broadcast Storms".

### 1. Decentralized Process Discovery (`pg`)
Integrate `pg` (Process Groups) or `Syn` to realize *Eventual Consistency* grouping. Eschew global dictionaries entirely. Discovery relies purely on structural inheritance (down the tree via `init/1` refs) and localized topics (stigmergy).

### 2. Supervision Trees and Hyper-Concurrency
Deploy `DynamicSupervisor` elements using the `:one_for_one` strategy for high-churn operational Motor Cells. Rely on the ERTS scheduler using the `+sbt tnnps` flag to strictly lock thread affinity, preventing catastrophic NUMA node traversal.

### 3. Dual-Protocol Communication Matrices
- **Peripheral NS:** Map `chumak` (ZeroMQ) for deterministic synaptic firing and precise prediction-error tracking ("Nociception") without message batching.
- **Central NS:** Map `tortoise` (NATS Core) for ambient endocrine gradients (tracking holistic cluster starvation and global metabolic pressure).

---

## PHASE 3: Declarative Genetics & The Metabolic Daemon
**Objective:** Establish physical hardware survival mechanisms and declarative cell scaling.

### 1. Epigenetic Transcription (YAML)
Implement the `YamlParser`. When a generic stem cell boots, it parses schemas from `config/genetics/*.yml`. This configures its valid execution commands, subscribed ZeroMQ queues, and target AST-parsing endpoints dynamically.

### 2. Utility Calculus & Digital Apoptosis
Instantiate the **Metabolic Daemon** (`gen_server`).
- **CPU Starvation Check:** Trigger localized Apoptosis if Erlang scheduler run queue wait time sequentially exceeds `5ms`.
- **L3 Cache Constriction:** Drop ambient NATS telemetry if native L3 cache misses spike, representing `Memgraph` thread-pointers suffocating cache-lines.
- **Digital Torpor:** If IOPS limits block XTDB commits $> 10ms$, the organism actively sheds speculative cells.

---

## PHASE 4: The Rhizome & Rust Organelles
**Objective:** Bridge the Elixir concurrency model to bare-metal bitemporal graph processing.

### 1. The FFI Boundary (`Rustler`)
Define secure pointers bridging Elixir to Rust. 
- Massive payloads are allocated on the native Rust heap. 
- The BEAM receives opaque Elixir Resource Objects interfacing directly with `#[repr(C)]` memory layouts. 
- All Rust functions exceeding `1ms` of compute time must explicitly yield to `SchedulerFlags::DirtyCpu` or `DirtyIo`.

### 2. Dual-Memory Orchestration
- **Active Memory (Tier-0):** Memgraph Integration managing real-time topology and structural Active Inference.
- **Archival Memory (Tier-1):** XTDB Integration using Anchor + Delta structures. Implement **Eager Version Pruning** to constantly mitigate MVCC chain bloat preventing memory exhaustion.

### 3. The Sleep Cycle Daemon
Offline Rust daemon traversing historical XTDB logs. Formulates deterministic application of **Louvain community detection**. Converts specific repeated episodic behaviors into monolithic "Super-Nodes", enabling accelerated inference.

---

## PHASE 5: Sensory I/O & The Sandbox Membrane
**Objective:** Establish deterministic perception and sovereign execution utilizing Firecracker microVMs.

### 1. The Sensory Perimeter
Integrate `Tree-sitter` within a Rust NIF for immediate, deterministic extraction of Abstract Syntax Trees (AST) directly mapped to graph nodes.

### 2. Motor Execution & Virtio-fs Bridging
Integrate AWS Firecracker (`firectl` bindings). 
- Strictly limit microVMs to 2 vCPUs and 512MB RAM.
- Ensure sandbox `eth0` drops outbound connections (Air-Gapped).
- Mount `.nexical/plan.yml` state files into the KVM guest via `Virtio-fs`.
- Pipe compilation stack traces back to the Karyon evaluation engine to generate formal prediction errors.

---

## PHASE 6: Testing, CI/CD, & Validation Strategy
**Objective:** Enforce the specific non-deterministic boundary checks required by biomimetic computing.

### 1. Property-Based Temporal Testing
- Integrate `stream_data` to auto-generate out-of-order ZeroMQ message permutations, mathematically verifying internal graph transaction ordering guarantees.
### 2. Cross-Boundary Memory Profiling
- Embed `Valgrind` LLVM sanitizations within the Rustler test suites proving Opaque Resource Objects deallocate safely without leaking memory during BEAM Garbage Collection sweeps.
### 3. Chaos Engineering (Apoptosis Proving)
- Build a CI/CD module that executes `Process.exit(pid, :kill)` against 10% of active cells under load to document OTP supervision regeneration efficiency.

---

## PHASE 7: Documentation & Operational Playbooks
**Objective:** Provide rigorous operational manuals enabling users to deploy, monitor, and scale the entity.

### 1. The Genetic Blueprint Guide
Detailed manual on authoring `.yml` configurations. How to structurally differentiate Stem Cells into Sensory vs. Motor Cells, define API endpoints, and establish validation bounds.
### 2. Metabolic Operations Playbook
Dashboard definitions. How to mathematically read the run queue signals, L3 cache drops, and XTDB starvation states to debug Apoptosis loops during production runtime.
### 3. Developer Endpoints & NIF Safety
Architecture documentation for the `Rustler` FFI boundaries and how to write new Organelles (e.g., integrating a custom Tree-sitter extension) without causing BEAM thread-locking or garbage-collection memory leaks.
