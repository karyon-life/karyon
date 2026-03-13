# Karyon Architectural Specification (SPEC.md)

This document serves as the definitive technical architecture and system boundaries reference for the Karyon AI project, translated from the theoretical biological paradigms into explicit engineering constraints.

## System Architecture & Hardware Topology

### 1. Hardware Constraints: The NUMA Imperative
To execute a biologically-scaled, cellular state machine relying on a lock-free temporal graph database, the Karyon architecture is physically limited by memory bandwidth constraints rather than compute throughput. 
- **Mandatory Processor:** Single-socket architectures (e.g., AMD Threadripper with 64-cores/128-threads).
- **Mandatory Memory topology:** 8-channel ECC RAM (DDR4/DDR5) to saturate the memory bus.
- **NUMA Avoidance:** Multi-socket NUMA arrays are explicitly forbidden for the active cell layer (Cytoplasm). Traversing sparse graph structures across socket interconnects triggers catastrophic cache-miss starvation and latency spikes (138-200ns+). Thread affinity must be strictly enforced (e.g., `+sbt tnnps` in BEAM) to ensure execution threads never cross logical silicon boundaries during real-time inference.

### 2. The Microkernel: The Sterile Engine
The core execution logic resides entirely within an immutable, microkernel architecture written in Elixir (running on the Erlang BEAM VM).
- **Absolute Sterility:** The compiled Elixir binary acts exclusively as the "physics engine" of the biological organism. It contains absolute zero domain-specific logic, AI heuristics, or hardcoded parsing strategies.
- **Orchestration Scope:** The microkernel's mandate is restricted strictly to:
  1. Managing the concurrent lifecycles of 500k+ lightweight Actor processes (stem cells/specialized cells).
  2. Routing asynchronous, lock-free messages via the internal nervous system.
  3. Formulating memory alterations to the isolated Rhizome graph based on external physical consequences.
- **Separation of Engine and Experience:** By decoupling knowledge from execution, the compiled footprint remains microscopic (under 15,000 LOC), insulating the system's fault-tolerant core from unpredictable LLM hallucination.

### 3. The Elixir/Rust Bridge (`Rustler` NIFs)
Because the Elixir/BEAM VM is optimized for highly concurrent network routing rather than CPU-bound mathematically intense executions, Karyon offloads structural cognition to Native Implemented Functions (NIFs) written in Rust.
- **The FFI Boundary:** The Foreign Function Interface (FFI) is facilitated via `Rustler`. 
  - **Elixir Duties:** System supervision, message routing, ZeroMQ/NATS brokering, and handling digital apoptosis triggers.
  - **Rust Duties:** All dense mathematical calculations, high-throughput graph database ingestions, layout-aligned hardware routines (exploiting SIMD AVX-512 via `#[repr(C)]`), and deterministic AST execution.
- **Zero-Copy Serialization:** To circumvent catastrophic Serialization/Deserialization (Serde) latency across the FFI, massive payloads (like millions of graph vertices or AST outputs) are allocated on the native Rust heap. Elixir processes receive an opaque, reference-counted "Resource Object" acting as a pointer, safely bypassing inter-language copying constraints.
- **Deterministic Parsing:** Sensory cells parse codebases exclusively utilizing deterministic Rust/C engines like Tree-sitter. The AST is mapped to graph nodes in Rust, remaining entirely invisible to the Elixir garbage collector. If a NIF exceeds BEAM scheduling times (e.g., 1ms), it must be explicitly offloaded to `SchedulerFlags::DirtyCpu` to prevent thread starvation.

## Concurrency, Routing, & State Management

### 1. The Nervous System (ZeroMQ & NATS)
To route information across 500k+ active cells without creating catastrophic lock contention, Karyon employs a strict zero-buffering, dual-tier message bus.
- **Peripheral Nervous System (ZeroMQ):** Used for sub-millisecond, peer-to-peer data streaming at the compute edge (e.g., routing neural tensors or high-bandwidth sensory payloads directly between adjacent cells). It is brokerless, embedded, and circumvents the bottleneck of centralized registries.
- **Central Nervous System (NATS Core):** Serves as the global control plane, handling ambient endocrine broadcasts (e.g., telemetry, metabolic pressure). It operates strictly in-memory with high-throughput (millions of messages/sec) and utilizes a QoS level 0 (at-most-once delivery).

### 2. The Actor Lifecycle & OTP Supervision
Karyon mandates the Elixir/BEAM Actor Model. Cells operate as isolated green threads communicating strictly via asynchronous message passing, ensuring no shared memory mutations outside of the Rust NIF boundaries.
- **Apoptosis (Programmed Cell Death):** Karyon strictly adheres to the Erlang "Let it Crash" philosophy. If an agent loops, hallucinates, or breaks logic, no attempt is made to rescue the thread. The process is immediately terminated.
- **OTP Supervision Trees:** The system leverages `one_for_one` and `rest_for_one` supervision strategies to instantly regenerate failed cells from a clean state. This prevents localized logic failures from cascading and destroying the broader execution topology.

### 3. Decentralized Routing & Component Discovery
Tracking 500,000+ dynamically spawning Actor processes presents a significant routing challenge.
- **Registry Bottlenecks:** Karyon explicitly forbids massive centralized registries (global dictionaries) for process tracking. These create immediate bottlenecks on the L3 cache and trigger catastrophic "Broadcast Storms" that suffocate processor bandwidth.
- **Decentralized Alternatives:** Routing must be executed via direct PID passing down the supervision tree, structural inheritance, Process Groups (`pg`), and stigmergy principles (reading localized state changes to determine peer activity rather than broadcasting).

## The Rhizome Memory & Metabolic Regulation

### 1. Dual-Layer Database Schema (Memgraph / XTDB)
Karyon discards dense matrices in favor of sparse, bitemporal graph structures to completely eradicate catastrophic forgetting.
- **Active Memory (Memgraph):** An in-RAM graph database supporting the immediate working memory of the organism. It enables millisecond-latency synaptic processing, Hebbian wiring, and structural Active Inference.
- **Archival History (XTDB):** An NVMe-backed temporal graph database providing a permanent bitemporal ledger (Transaction Time and Valid Time). It functions as the permanent repository for consolidated algorithmic experience.

### 2. Multi-Version Concurrency Control (MVCC)
To permit 500k+ cells to continuously mutate and traverse the Rhizome simultaneously without locking, Karyon strictly mandates an MVCC architecture.
- **Anchor + Delta Storage:** Minimizes the memory footprint of temporal tracking by storing base states (anchors) and logging sequential alterations (deltas).
- **Eager Version Pruning:** Crucial for mitigating MVCC version chain bloat and surviving "mammoth transactions." Karyon aggressively reclaims temporal dead-zones to prevent rapid host memory exhaustion.

### 3. The Consolidation Daemon (Sleep Cycle)
Karyon mimics biological sleep to transfer short-term working state into long-term systemic abstractions.
- **Louvain Community Detection:** Offline Rust daemons continuously sweep the historical XTDB graph, identifying clusters of localized nodes that frequently fire together (e.g., repeating syntax blocks).
- **Super-Node Generation:** The daemon collapses these intricate sub-graphs into highly abstracted "Super-Nodes," allowing active Motor Cells to reason using complex concepts rather than granular steps.

### 4. Utility Calculus (Digital Metabolism)
Karyon prevents the runaway resource saturation typical of containerized architectures via a hardcoded internal metabolism.
- **ATP Analogue:** The system measures its available "energy" by tracking CPU scheduler run queues, L3 cache misses, and XTDB disk I/O metrics.
- **Apoptosis:** If ATP drops, the organism executes programmed cell death, terminating speculative or low-utility processing cells to instantly reclaim CPU cycles and memory bandwidth.
- **Digital Torpor:** During severe hardware starvation or catastrophic Broadcast Storms, Karyon sheds network operations entirely, severing listeners to protect its core intelligence until homeostasis returns.

## Epigenetics, Sensory I/O, & Sandboxing

### 1. Declarative Genetics (YAML Schemas)
Karyon agents are not hardcoded Python classes. Cellular differentiation is governed by the Epigenetic Supervisor utilizing declarative YAML "DNA" files.
- **Stem Cell Differentiation:** A base Elixir Actor (stem cell) reads a declarative configuration to transform into a highly specialized unit (e.g., an Eye parser or a Motor executor) dynamically at runtime, divorcing behavioral rule-sets from compiled engine logic.

### 2. The Sensory Perimeter
Karyon forces a strict biological separation of concerns between reasoning and perception to eliminate structural hallucination.
- **The Eyes (Deterministic AST):** Heavily specialized Rust cells utilizing Tree-sitter to ingest target codebases. These cells deterministically translate raw text directly into 100% accurate, hallucination-free graph topology.
- **The Ears (Passive Telemetry):** Hardcoded ZeroMQ and NATS listeners that passively absorb environmental noise (webhooks, server logs) and synthesize them into relational facts for immediate insertion into Memgraph.
- **The Skin (Spatial Poolers):** For unknown or undocumented protocols, Karyon deploys highly quantized, small-parameter models (e.g., 3B parameter GGUF models on CPU via `llama.cpp`). These function exclusively as an untargeted sensory layer, utilizing continuous Hebbian learning to map statistical proximities into physical graph edges. They are never utilized for internal architectural logic.

### 3. The Membrane of Irreversible Action (The Sandbox)
Karyon is explicitly forbidden from generating code or mutating the global host execution environment directly.
- **Ephemeral KVM Micro-VMs:** Motor cells formulate codebase patches within strictly isolated, disposable KVM/QEMU Virtual Machines (e.g., Firecracker). Shared-kernel Docker containers are explicitly rejected due to security vulnerability.
- **Virtio-fs Bridging:** The organism interacts with the isolated workspace solely via Virtio-fs. 
- **Execution Telemetry:** Karyon triggers compilers or test suites within the micro-VM. If the pipeline succeeds, the graph pathways are hardened. If a stack trace occurs, the system experiences a high-precision "Prediction Error," instantly triggering Fisher Information pruning on the failed graph connections.

## Enterprise Strategy & Ecosystem

### 1. Licensing Structure (AGPLv3 vs. Commercial)
To ensure the integrity of the open-source Karyon ecosystem while providing a sustainable enterprise model, the codebase utilizes a dual-licensing strategy.
- **The Core Engine (AGPLv3):** The base Elixir Cytoplasm and Rust Organelles (the sterile physics engine) are licensed under AGPLv3. This guarantees that any localized modifications to the core routing or memory management layers must remain open-source.
- **Enterprise Features (Proprietary/Commercial):** Advanced multi-tenant orchestration, highly optimized GGUF spatial pooler models, and specialized enterprise CI/CD integration bindings are reserved for commercial licensing.

### 2. Air-Gapped Execution & Local Entity Constraints
Karyon provides true data sovereignty for enterprise environments by completely decoupling the execution engine from the memory state.
- **The Engine (`/karyon/bin/`):** The compiled sterile microkernel operates without any external network dependencies.
- **The Living Entity (`~/.karyon/`):** All active state, history (`.nexical/history/`), and overarching YAML objectives are stored exclusively on the local filesystem. This architecture inherently supports fully air-gapped deployments, guaranteeing that proprietary corporate codebases never leave the internal network.

### 3. The Engram Distribution Model
Karyon shares acquired intelligence not through statistical model weights, but via distributable, topological experience graphs.
- **Exporting Experienced Graphs:** Background extraction daemons serialize mature architectural knowledge regions from the XTDB temporal graph into highly compressed `.engram` packages (e.g., `python_experience_v1.engram`). 
- **Sovereign Implantation:** These engrams contain zero core execution logic and no telemetry data—only abstracted architectural topology. They can be safely injected into a blank, air-gapped Karyon instance, instantly passing on structural mastery without requiring cloud connectivity or exposing raw training source code.

## Engineering Standards & Protocols

To guarantee structural consistency and modular high-quality development, all applications extending the Karyon architecture must adhere to the following explicit engineering constraints. 

### 1. Concrete API Boundaries & Data Contracts
The Karyon physics engine requires unambiguous communication contracts.
- **The Rustler FFI Boundary:** 
  - Graph pointers and payload structs passed between Elixir and Rust must strictly use `#[repr(C)]` memory layouts.
  - Rust NIFs must never panic. All bounds-checking failures, parsing errors, or missing nodes must return an explicit `{:error, reason}` Erlang tuple.
  - Any Rust traversal or string manipulation logic that exceeds `1ms` of CPU time must be explicitly wrapped in `SchedulerFlags::DirtyCpu`. Any disk-bound IO (like writing an XTDB delta block) must be explicitly flagged with `SchedulerFlags::DirtyIo`.
- **Nervous System Serialization:** 
  - ZeroMQ (Peripheral) and NATS (Central) payloads cannot be arbitrary strings. Every signal (e.g., `PredictionError`, `MetabolicSpike`) must adhere to a strict typed schema via **Protocol Buffers** or rigorously typed JSON schema validation to guarantee 500k-cell interoperability.

### 2. Standardized Project & Monorepo Structure
Any Karyon application must isolate its sterile logic from its DNA and data states physically on disk.
The monorepo structure is unyielding:
- `app/mix.exs`: Umbrella root manifest.
- `apps/core/lib/`: Exclusively Elixir Cytoplasm logic (routing, process trees).
- `apps/rhizome/native/`: Exclusively Rust Organelles (`Cargo.toml`, Memory/Graph NIFs).
- `priv/dna/`: Immutable YAML genetic schemas defining cell types.
- `~/.karyon/`: The external, stateful Living Entity (never checked into version control).

### 3. Declarative Schema Definitions (DNA)
Cellular roles are prohibited from being statically compiled. They must be rendered dynamically via YAML `DNA` schemas.
A base `[Cell_Type].yml` schema must rigidly define:
- `subscriptions:` (Which NATS/ZeroMQ topics the process listens to).
- `allowed_actions:` (Which external APIs or physical boundaries the cell may interact with).
- `ast_parser:` (Which specific `Tree-sitter` Rust NIF is utilized to observe its environment).
An `[Objective].yml` schema must rigidly define high-weight topological Attractor States that trigger planning cell navigation.

### 4. Deterministic Testing & CI/CD Mandates
Testing a biological, asynchronous, bitemporal state machine requires specialized CI gates prior to merging code into `main`.
- **Property-Based Testing:** Elixir implementations must use `stream_data` or `PropEr` to generate millions of randomized, out-of-order ZeroMQ message permutations to verify internal graph transaction ordering guarantees.
- **Memory Profiling:** Ensure `Valgrind` or equivalent LLVM memory sanitizers are used within the rustler test suites to mathematically verify that the opaque `Resource Objects` safely deallocate without leaking memory during the Erlang Garbage Collection sweep.
- **Chaos Engineering (Apoptosis Validation):** Automated CI pipelines must sporadically execute `Process.exit(pid, :kill)` against 10% of active BEAM cells under load to mathematically prove the OTP Supervision trees dynamically reconstruct the topological mapping without dead-locking.

### 5. Explicit "Metabolic Pain" Thresholds
Karyon applications must define their homeostasis baselines. The Default Threadripper thresholds for the Metabolic Daemon are:
- **CPU Starvation:** Trigger `Apoptosis` of low-utility speculative cells immediately if the Erlang scheduler run queue wait time sequentially exceeds `5ms`.
- **L3 Cache Constriction:** Drop non-essential ZeroMQ listeners if native L3 cache misses spike `> X%` beyond the established baseline, indicating that `Memgraph` thread-pointers are suffocating the CPU cache-lines.
- **IOPS Backpressure:** If Virtio-fs or NVMe XTDB archive writes exceed `X` IOPS (or cause transaction locks > 10ms), switch the organism into `Digital Torpor`, ignoring ambient NATS telemetry to preserve core intelligence.

### 6. Sandbox Security Profiles
All Motor cell mutation processes that generate patches or compile tests must execute in disposable AWS Firecracker micro-VMs.
- **MicroVM Hard Limits:**
  - Maximum 2 vCPUs allowed per ephemeral sandbox.
  - Strict 512MB RAM limitation per sandbox to force memory-efficient compilation tests.
- **Network Air-Gap:** Sandbox `eth0` network namespaces must drop all outbound connections. The compilation sandbox has zero internet access.
- **I/O Bridge:** Interactions exist strictly over a local `Virtio-fs` socket mount limited to target workspace directories (e.g., `/mnt/workspace/`) to prevent host-os corruption.
