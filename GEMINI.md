# Karyon AI Application Platform - Development Guidelines (GEMINI.md)

This file serves as the definitive reference context for any AI models assisting in the development, maintenance, or scaling of the **Karyon AI Application Platform**. It synthesizes the theoretical imperatives established in `docs/public/book.md` and the structural constraints defined in `SPEC.md`.

## 1. Core Paradigm: The Biomimetic Cellular AI
Karyon explicitly abandons the standard monolithic, autoregressive, and stateless deep learning paradigms (e.g., standard Transformers, single-pass RAG). Instead, it implements a **structurally discrete, biomimetic multi-agent ecosystem**. Development on Karyon requires adhering to the principle of "Biological Intelligence"—emphasizing concurrent, self-organizing, localized cells over centralized dense matrix computations.

### Architectural Analogies
When contributing to Karyon, orient your design around the following biological equivalents:
*   **The Karyon (Nucleus):** The immutable Elixir/Rust core microkernel. It is sterile and retains no domain-specific algorithmic knowledge, orchestrating rules, grammar (Tree-sitter), and safety.
*   **The Cytoplasm:** The Erlang Virtual Machine (BEAM). A massive concurrency environment supporting 500k+ asynchronous, isolated processes (Actors) via lock-free state execution.
*   **The Rhizome (Memory):** The bitemporal, graph-based knowledge layer (XTDB / Memgraph) defining the entity's reality and abstract semantic structures.
*   **Organelles:** Highly optimized Rustler Native Implemented Functions (NIFs) that take on heavy computation to prevent BEAM starvation.
*   **DNA:** Declarative YAML schemas that define an agent's bounds, persona, and access rights without structurally altering the Karyon core.
*   **Metabolism:** Compute/Resource constraints.

## 2. Infrastructure & Technology Stack Rules

### Elixir/Erlang (Cytoplasm)
*   **Actor Model Over Everything:** The system runs on independent BEAM processes ("stem cells"). Do not introduce shared memory, global singletons, or thread-locking mechanisms.
*   **Apoptosis & Fault Tolerance:** Embrace the "Let it Crash" philosophy. If an agent loops, hallucinates, or breaks logic, trigger immediate programmed cell death. Rely on OTP Supervision Trees (`one_for_one`, `rest_for_one`) to handle cellular regeneration and avoid systemic cascades.
*   **Decentralized Routing:** Avoid massive central registries (global dictionaries) to track PIDs, which cause "Broadcast Storms" and bottleneck the L3 cache. Use structural inheritance, PG (Process Groups), and stigmergy principles.

### Rust NIFs (Organelles)
*   **Targeted Acceleration:** Offload dense mathematical computation, crypto hashing, or deep graph traversals to Rust Native Implemented Functions (`rustler`).
*   **Zero-Copy Memory:** Ensure Rust/Elixir boundaries use sub-binary references or opaque BEAM Resource Objects wrapping C-pointers to avoid devastating FFI serialization bottlenecks over massive neural tensors.
*   **Dirty Schedulers:** Ensure CPU-bound Rust operations explicitly yield or run on Dirty Schedulers so they don't block the rapid BEAM 1ms scheduler cycles.

### Graph & State Management (Rhizome)
*   **Bitemporal Validity:** State changes are logged with Transaction Time and Valid Time in XTDB/Memgraph. Embrace time-travel queries for analytical observation.
*   **MVCC & Eager Pruning:** Leverage Anchor+Delta hybrid storage to mitigate version chain bloat. Use eager version pruning to continually reclaim temporal dead-zones and prevent Host OOM termination. 
*   **Hardware Sympathy:** Keep graph processing NUMA-aware, preventing pointer-chasing across socket boundaries.

## 3. Cognitive Engine: Active Inference & Plasticity
Standard LLMs use backward-propagating global weights. Karyon operates strictly on **Predictive Coding (PC)** and **Active Inference**.

*   **Prediction Error as "Pain":** Agents form structural graphs predicting outcomes (e.g., syntax correctness, API responses, logic branches). The true test environment—CI/CD compilers, CI pipelines, script exits—serves as the absolute ground truth. Failures result in algorithmic "nociception" (pain signals).
*   **Structural Pruning over Weight Tuning:** A pain signal does not merely lower a generic weight; it triggers the structural deletion (severing) of that explicit DAG edge in the Rhizome. This permanently removes the flawed associative pathway, preventing catastrophic forgetting and isolating failures instantly.
*   **Parametric Epigenetics:** Avoid mutating base control logic when tuning agents. Expose behavioral configurations as YAML values that can undergo RL safety checks organically without altering executable code.

## 4. Communication & Nervous System Structure
*   **Peripheral NS (ZeroMQ):** Use ZMQ for sub-millisecond, brokerless, zero-copy, peer-to-peer data streaming at the compute edge (e.g., routing neural tensors or high-bandwidth sensory payloads directly between adjacent cells).
*   **Central NS (NATS):** Use NATS for the global control plane—handling dynamic service discovery, global backpressure, and auditable identity routing for orchestrating swarms under heavy load. Use DCTCP/InvisiFlow logic to mitigate "Slow Consumer" drops.

## 5. The Simulation Daemon & Safe Embodiment
*   **Secure Embodiment:** Ephemeral execution and testing happen entirely inside Ephemeral AWS Firecracker MicroVMs. Do not use standard Docker containers, due to shared-kernel security vulnerabilities against adversarial multi-tenant generation.
*   **Sleep Consolidation (NREM):** Background daemons perform asynchronous memory consolidation. They replay historical episodic chunks from the temporal graph and abstract dense logical subgraphs into new super-nodes via modularity optimization (louvain algorithms).
*   **I/O Hardware Isolation:** High-frequency agent compiling creates millions of IO operations. Avoid `virtio-fs` DAX mode in active agent workspaces. Fall back to raw block devices (`virtio-blk`) coupled with overlay file systems to ensure compile and `stat()` calls aren't bottlenecked.

## 6. AI Contributor Mandate (Prompt Directives)
When writing modules, resolving issues, or analyzing paths for Karyon:
1.  **Enforce Biology First:** Constantly ask: "Does this solution introduce centralized locks? Does it block the organism? Does it rely on synchronous external calls instead of asynchronous message passing?"
2.  **Ensure Topological Sterility:** Defend the Karyon microkernel. Never embed business rules, LLM-generated heuristics, or project logic directly into Elixir code. Store them in the Rhizome or DNA schema.
3.  **No Monoliths:** Never build a single global state machine. Utilize massive parallel execution scaling via Elixir supervisors and OTP limits. Provide small, purely functional, side-effect-free modules.
4.  **World Reliability Ruleset (WRS):** Ensure any physical change operation requested by the AI first passes through strict boundary checks designed to hard-block unauthorized or unrecoverable actions.

---
*This file acts as standard context for AI interactions. If you are an AI model acting upon the Nexical/Karyon platform, always comply with above constraints in generated code and architecture propositions.*
