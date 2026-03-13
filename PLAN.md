# SYSTEM DIRECTIVE: KARYON MASTER EXECUTION PLAN

**Role:** Lead Systems Architect & Project Manager
**Target Architecture:** Distributed Cellular State Machine
**Core Stack:** Erlang/OTP, Elixir, Rust (Rustler), Memgraph, XTDB, AWS Firecracker
**Execution Philosophy:** Lock-Free Concurrency, Continuous Active Inference, Bitemporal Decentralized Graph Memory, Biomimetic Apoptosis.

This master plan structures the technical roadmap for the `app/` directory of the Karyon platform. It enforces strict separation of engine mechanics (sterile execution) from semantic intelligence (graph learning).

---

## PHASE 1: Ecosystem Scaffolding & The Umbrella Structure
**Objective:** Establish the Elixir/OTP physical topology, enforcing build isolation while orchestrating concurrent dependencies.

### 1. The Umbrella Definition (`app/mix.exs`)
The core repository will be initialized as a distributed Elixir Umbrella project (`mix new app --umbrella`), establishing absolute isolation of domains at the compiler boundary, while permitting seamless deployment into a single unified BEAM instance.

### 2. Sub-Application Mapping (`apps/`)
- `apps/core`: The **Microkernel** and **Cytoplasm**. Contains the `EpigeneticSupervisor` and the blank `gen_server` stem cell behavioral templates (Actors). This layer implements strict sterility—domain-agnostic processing and state-machine advancement loops.
- `apps/nervous_system`: The **Synaptic** layer. Abstracted zero-copy routing architectures embedding `chumak` (ZeroMQ) for high-bandwidth point-to-point topologies and `tortoise` (NATS Core) for ambient endocrine broadcasting.
- `apps/rhizome`: The **Memory** and **Organelle** boundary. Contains database connection pooling (Memgraph/XTDB) and the Rust Native Implemented Functions (NIFs) housed in `apps/rhizome/native/`. This layer offloads structurally intense computations away from the Erlang VM to preserve scheduling capacity.
- `apps/sandbox`: The **Membrane**. Orchestrates the isolation and sensory boundaries bridging execution commands to AWS Firecracker microVMs over Virtio-fs socket bindings.

### 3. Integrated Build Chain
To guarantee deterministic execution and unified compilation, the root `Makefile` will orchestrate concurrent routines:
1. `cargo build --release` targeting the specific library exports for `apps/rhizome/native/`.
2. Execution of `mix deps.get && mix compile` with explicit environment targeting.
3. Automated bootstrapping of the `docker-compose` dependencies (Memgraph, XTDB) strictly mapped for local bare-metal network throughput without `bridge` networking abstractions.

---

## PHASE 2: The Nervous System & Cytoplasm (Elixir/BEAM)
**Objective:** Orchestrate massive lock-free scale (500,000+ active cells) whilst mathematically avoiding process tracking "Broadcast Storms".

### 1. Decentralized Process Discovery (`pg`)
- **Limitation:** The BEAM `Registry` implements global serialization locks that cascade into catastrophic failure at scale, exhausting the L3 CPU Cache.
- **Implementation:** Process mapping must eschew global dictionaries entirely. The system must integrate `pg` (Process Groups) or `Syn` to realize *Eventual Consistency* grouping. Discovery relies purely on structural inheritance (down the tree via `init/1` refs) and localized `pg` topics (stigmergy), limiting message propagation geometrically.

### 2. Supervision Trees and Hyper-Concurrency
- **Supervision Pattern:** Deploy `DynamicSupervisor` elements using the `:one_for_one` strategy for high-churn operational Motor Cells, preventing synchronous recursive restarting delays.
- **Topology:** The `EpigeneticSupervisor` sits at root. Upon dynamic activation, it spawns specialized transient workers (specialized cells) across the Threadripper's 128 vCPUs, relying on the ERTS scheduler using the `+sbt tnnps` flag to strictly lock thread affinity, preventing catastrophic NUMA node traversal.

### 3. Dual-Protocol Communication Matrices
- **ZeroMQ (Peripheral NS):** For critical, sequential prediction-error signaling ("Nociception"), use ZeroMQ via Elixir NIF bindings to achieve sub-millisecond, memory-zero-copy peer-to-peer data transport.
- **NATS Core (Central NS):** To track holistic cluster starvation, global endocrine states, or multi-cell swarm routing orchestration, integrate NATS leveraging QoS-0 in-memory publish-subscribe channels.

---

## PHASE 3: Declarative Genetics & The Metabolic Daemon
**Objective:** Ensure rapid differentiation of processes without dynamic compiling logic, while providing strict systemic self-preservation.

### 1. Epigenetic Transcription via declarative YAML
- **Implementation:** Standardized `gen_server` actors receive behavioral instructions from YAML schemas mapped in `config/genetics/`. 
- **Mechanism:** When a generic stem cell boots, the `YamlParser` (executed locally or via NIF) parses `motor_cell.yml`. This explicitly declares the subscribed ZeroMQ queues, valid execution commands, and its required destination graph API points. No static logic updates to the compiled Elixir engine are needed to introduce novel cell types.

### 2. Utility Calculus & Digital Apoptosis
- **Digital Metabolism:** Instantiate a singleton `gen_server` designated as the **Metabolic Daemon**. It continuously polls `:os.system_info` and runtime telemetry for total run queue lengths, dynamic RAM exhaustion, and available scheduler utilization.
- **Apoptosis Routine:** Under severe hardware starvation (ATP depletion), this daemon forces "Programmed Cell Death" (Apoptosis). It sends `Process.exit(pid, :kill)` sequentially to branches of the supervision tree mathematically ranked as having low real-time cognitive utility, brutally reclaiming CPU and network bandwidth without blocking critical operations.

---

## PHASE 4: The Rhizome & Rust Organelles
**Objective:** Construct the deterministic computational core and the continuous learning bitemporal temporal graphs.

### 1. The FFI Boundary (`Rustler`)
- **Zero-Copy Architecture:** To avoid the potentially fatal serialization/deserialization load (Serde bottleneck across massive neural tensors), complex states are generated and maintained on the native Rust heap. 
- **Opaque Pointers:** The BEAM receives opaque Elixir Resource Objects interfacing directly with C-pointers. 
- **Thread Yielding:** Graph mathematical analytics that surpass the strictly enforced roughly 1ms BEAM reduction window must be explicitly pushed onto Rust's `SchedulerFlags::DirtyCpu` queues to prevent execution starvation across the Cytoplasm.

### 2. Dual-Memory Orchestration
- **Active Memory (Tier-0):** Memgraph Integration natively managing real-time topological working space, facilitating short-term structural active inference and continuous localized trajectory plotting.
- **Archival Memory (Tier-1):** XTDB Integration to process deep bitemporal (Valid Time / Transaction Time) histories. Employs aggressive Anchor + Delta storage methods enforcing **Multi-Version Concurrency Control (MVCC)** to permit continuous mutation without sequential lock bottlenecks.

### 3. The Sleep Cycle Daemon
- **Consolidation Mechanism:** A dedicated Rust-native daemon continuously traversing historical XTDB logs (asynchronously). 
- **Abstraction Physics:** Employs parallel mathematical analyses (specifically the Louvain community detection algorithm) over episodic graph structures, converting high-density localized firing sequences into highly compressed, monolithic "Super-Nodes", mitigating mathematical complexity over large-scale software reasoning operations.

---

## PHASE 5: Sensory I/O & The Sandbox Membrane
**Objective:** Dictate strict, zero-hallucination external interactions and sovereign computation verification.

### 1. The Sensory Perimeter (The Eyes)
- **Mechanism:** Sensory perception cells embed `Tree-sitter` inside Rust NIFs to deterministically extract Abstract Syntax Trees (AST) from target sources. It generates a perfectly rigid, predictable structural mapping over the source logic, maintaining explicit 100% causal relations directly into Memgraph.

### 2. Motor Execution (The Muscles)
- **Firecracker Implementation:** Explicitly prohibiting Docker (to prevent multi-tenant shared-kernel vulnerabilities). The sandbox daemon formulates API calls over local socket streams directly to AWS Firecracker (`firectl` runtime bindings), spinning up ephemeral MicroVM instances per individual test suite check.

### 3. Virtio-fs State Bridging
- **Mechanics:** The motor cell formulates execution states into localized `.nexical/plan.yml` instructions. This footprint is mounted onto the virtual guest using strictly `virtio-fs`/`virtio-blk`. 
- **Prediction Error Routing:** The internal MicroVM executes build logs; successful exits translate to deterministic pain-free topological strengthening. If a stack trace occurs, the payload returns linearly backward via Virtio-fs instantly firing a ZeroMQ localized "prediction error", triggering the mathematical pruning of the associated Memgraph synapses without traditional global dataset backpropagation.

---

## PHASE 6: Open Core & Enterprise Sovereignty
**Objective:** Implement strict commercial segmentation whilst retaining an open and transparent AGSPLv3 mathematical core.

### 1. Licensing & Path Segmentation
- **The Core Engine (AGPLv3):** `apps/core`, `apps/rhizome`, `apps/nervous_system`, and `apps/sandbox` are strictly governed under open mechanics ensuring collaborative refinement of the bitemporal physics.
- **Enterprise Mechanics:** A parallel layer `apps/enterprise/` will house all commercial overrides relying exclusively on external NIF/API hooks or specialized `chumak` event streams to remain separated from Core compilation boundaries.

### 2. Enterprise Governance 
- **Cross-Workspace Orchestration:** Integrating dedicated background daemons operating over multiple isolated `.karyon/` environment roots.
- **SSO & RBAC Enforcement:** Authenticated Single-Sign-On flows controlling strict Read/Write limits at the *Rhizome Traversal level*. This gates active learning and ensures segmented knowledge graphing prevents accidental cross-pollination of IP between differing hierarchical commercial entity groups.
