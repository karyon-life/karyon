# Karyon Developer

> This document is auto-generated from the Karyon docs source.

# Chapter 1 Conformance

This document captures the Chapter 1 conformance gate for:

- `docs/src/content/docs/part-1/chapter-1/1-introduction.md`
- `docs/src/content/docs/part-1/chapter-1/2-the-statistical-dead-end.md`
- `docs/src/content/docs/part-1/chapter-1/3-catastrophic-forgetting-and-hardware-economics.md`
- `docs/src/content/docs/part-1/chapter-1/4-why-current-ai-fails-predictive-coding-and-active-inference.md`
- `docs/src/content/docs/part-1/chapter-1/5-chapter-wrap-up.md`

Chapter 1 conformance requires these behaviors:

- Planning is graph-backed and uses typed attractor and step contracts.
- Cells retain and recover lineage state from durable memory.
- Execution respects DNA `atp_requirement` before action.
- Nociception and execution failures persist typed prediction errors through the memory pipeline.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter1.conformance
```

This suite is expected to fail when:

- Prompt-response orchestration reappears inside the planning boundary.
- Cells stop checkpointing durable state or fail to recover lineage state after restart.
- Execution bypasses ATP admission or prediction errors bypass typed persistence.
- New prompt, completion, or chat-style APIs enter the planning, execution, or memory boundary.

The GitHub Actions workflow `chapter1-conformance.yml` must pass on pushes and pull requests.

---

# Chapter 2 Conformance

This document defines the regression boundaries derived from Part 1 Chapter 2 of the Karyon book source at `docs/src/content/docs/part-1/chapter-2/**`.

## Forbidden Regressions

Do not introduce any of the following into the Chapter 2 cognition loop:

- Centralized cell discovery that bypasses structured `:pg` routing.
- Prediction-error handling that ignores expectation lineage, objective weights, or nociception metadata.
- Planning that collapses abstract states back into flat string goals without typed target-state or predicted-state contracts.
- Pointer-based placeholder plasticity in the active cell loop instead of explicit reinforce/prune pathway operations.
- Global retraining-style shortcuts that bypass local, forward-only pathway mutation.

## Required Invariants

Chapter 2 conformance requires these behaviors:

- Cells advertise and discover peers through structured `:pg` topics.
- Predictive processing uses typed expectations, weighted surprise, and persisted expectation lineage.
- Plans carry typed abstract states, weighted needs, weighted values, and objective priors.
- The pain receptor filters recursive pain signals and emits enriched nociception metadata.
- Plasticity uses explicit `reinforce_pathway/1` and `prune_pathway/1` mutations at the Rhizome boundary.

## Enforcement

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter2.conformance
```

CI requirement:

- The GitHub Actions workflow `chapter2-conformance.yml` must pass on pushes and pull requests that touch the repository.

---

# Chapter 3 Conformance

This document captures the Chapter 3 conformance gate for:

- `docs/src/content/docs/part-2/chapter-3/1-introduction.md`
- `docs/src/content/docs/part-2/chapter-3/2-the-microkernel-philosophy.md`
- `docs/src/content/docs/part-2/chapter-3/3-why-erlang-beam-is-the-perfect-cytoplasm.md`
- `docs/src/content/docs/part-2/chapter-3/4-why-rust-nifs-are-the-perfect-organelles.md`
- `docs/src/content/docs/part-2/chapter-3/5-the-membrane-firecracker-qemu-and-kvm.md`
- `docs/src/content/docs/part-2/chapter-3/6-the-nervous-system-distributed-cognition.md`
- `docs/src/content/docs/part-2/chapter-3/7-chapter-wrap-up.md`

Chapter 3 conformance requires these behaviors:

- The subsystem boundary contract keeps nucleus, cytoplasm, organelles, membrane, nervous system, and Rhizome ownership explicit.
- The microkernel stays sterile and uses declarative DNA executor contracts instead of embedding membrane logic directly in core cells.
- The cytoplasm preserves supervised, crash-oriented actor churn and decentralized discovery.
- Rust organelles remain dirty-scheduler-safe, typed, and panic-contained at the BEAM boundary.
- The Firecracker membrane uses the resolved `virtio-blk` plus overlay workspace contract.
- The nervous system preserves ZeroMQ and NATS transport separation with explicit runtime transport telemetry.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter3.conformance
```

This suite is expected to fail when:

- Subsystem ownership drifts back into ambiguous or overlapping boundaries.
- Core cells start depending directly on sandbox or Firecracker implementation details.
- Supervision, process-group routing, or churn resilience regresses.
- NIFs block schedulers or reintroduce panic-prone boundary behavior.
- The membrane stops honoring the `virtio-blk` workspace contract.
- The nervous system loses runtime transport descriptors, telemetry, or broker separation.

The GitHub Actions workflow `chapter3-conformance.yml` must pass on pushes and pull requests.

---

# Chapter 4 Conformance

This document captures the Chapter 4 regulation gate for:

- `docs/src/content/docs/part-2/chapter-4/1-introduction.md`
- `docs/src/content/docs/part-2/chapter-4/2-declarative-genetics.md`
- `docs/src/content/docs/part-2/chapter-4/3-the-epigenetic-supervisor.md`
- `docs/src/content/docs/part-2/chapter-4/4-apoptosis-digital-torpor.md`
- `docs/src/content/docs/part-2/chapter-4/5-chapter-wrap-up.md`

Chapter 4 conformance requires these behaviors:

- DNA remains the authoritative schema for role, policy, inheritance, and executor bounds.
- The epigenetic supervisor selects differentiated DNA variants from environmental pressure and role context instead of uniformly spawning a single generic cell.
- Differentiation decisions are persisted through the Rhizome boundary.
- Lifecycle state is explicit across `:active`, `:torpor`, `:revived`, `:shed`, and `:terminated`.
- Safety-critical cells are preserved under high pressure, while speculative or lower-priority cells are shed or pruned deterministically.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter4.conformance
```

This suite is expected to fail when:

- DNA validation becomes partial, ad hoc, or bypassable.
- Supervisor differentiation ignores environmental pressure or requested role context.
- Differentiation decisions stop being persisted into the Rhizome.
- Torpor, revival, shed, or termination semantics regress into implicit or inconsistent behavior.

The GitHub Actions workflow `chapter4-conformance.yml` must pass on pushes and pull requests that touch the repository.

---

# Chapter 5 Conformance

This document captures the Chapter 5 temporal graph gate for:

- `docs/src/content/docs/part-3/chapter-5/1-introduction.md`
- `docs/src/content/docs/part-3/chapter-5/2-graph-vs-matrix.md`
- `docs/src/content/docs/part-3/chapter-5/3-working-memory-vs-archive.md`
- `docs/src/content/docs/part-3/chapter-5/4-multi-version-concurrency-control.md`
- `docs/src/content/docs/part-3/chapter-5/5-chapter-wrap-up.md`

Chapter 5 conformance requires these behaviors:

- The Rhizome exposes an explicit topology contract for working memory, archive, and projection.
- The high-level memory boundary rejects opaque graph and archive shortcuts in favor of typed graph and archive operations.
- Working-memory operations, archive operations, and bridge operations remain distinct APIs.
- Archive writes append revisions with `xt/id`, `xt/revision`, `xt/valid_time`, and `xt/tx_time` metadata.
- Archive queries resolve latest-state by default and can expose full history or `as_of` temporal views when requested.
- Service-backed temporal validation must run when Memgraph and XTDB are reachable.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter5.conformance
```

This suite is expected to fail when:

- Working-memory and archive semantics collapse back into store-specific or blob-oriented helper calls.
- The Rhizome starts accepting opaque Cypher strings or archive JSON blobs through the high-level memory boundary.
- Archive writes regress into destructive update assumptions rather than revisioned append semantics.
- Latest-state, history, or `as_of` temporal reads stop matching the revision stream.

The GitHub Actions workflow `chapter5-conformance.yml` must pass on pushes and pull requests. It runs the service-backed temporal suites automatically when Memgraph and XTDB are reachable in the current environment.

---

# Chapter 6 Conformance

This document captures the Chapter 6 adaptive-map gate for:

- `docs/src/content/docs/part-3/chapter-6/1-introduction.md`
- `docs/src/content/docs/part-3/chapter-6/2-hebbian-wiring-spatial-pooling.md`
- `docs/src/content/docs/part-3/chapter-6/3-the-pain-receptor.md`
- `docs/src/content/docs/part-3/chapter-6/4-the-sleep-cycle-memory-consolidation.md`
- `docs/src/content/docs/part-3/chapter-6/5-chapter-wrap-up.md`

Chapter 6 conformance requires these behaviors:

- Repeated sensory structure is consolidated into pooled graph abstractions instead of remaining flat quantized events.
- Pain remains a typed prediction-error path with stable metadata and direct graph-correction linkage.
- Live learning and offline sleep-cycle consolidation both operate on the same Rhizome semantics.
- Sleep consolidation generates abstractions and archival projection without regressing back to blunt deletion.
- When Memgraph, XTDB, and NATS are reachable, the service-backed adaptive-map tests must also pass.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter6.conformance
```

This suite is expected to fail when:

- Spatial pooling stops reinforcing or persisting repeated structural patterns.
- Pain signaling loses typed metadata, duplicate suppression, or graph-correction persistence.
- Consolidation regresses into opaque side effects or destructive delete semantics.
- Service-backed recovery or Rhizome archive retention drifts away from the Chapter 6 adaptive-map contract.

The GitHub Actions workflow `chapter6-conformance.yml` must pass on pushes and pull requests.

---

# Chapter 7 Conformance

This document captures the Chapter 7 sensory gate for:

- `docs/src/content/docs/part-4/chapter-7/1-introduction.md`
- `docs/src/content/docs/part-4/chapter-7/2-the-eyes-deterministic-parsing.md`
- `docs/src/content/docs/part-4/chapter-7/3-the-ears-telemetry-events.md`
- `docs/src/content/docs/part-4/chapter-7/4-the-skin-spatial-poolers.md`
- `docs/src/content/docs/part-4/chapter-7/5-chapter-wrap-up.md`

Chapter 7 conformance requires these behaviors:

- The sensory perimeter remains explicit, bounded, and enforced by policy.
- The Eyes deterministically parse repositories and project repository/file/AST topology without hallucinated structure.
- The Ears normalize telemetry, logs, and webhook payloads into typed sensory events before Rhizome projection.
- The Skin discovers repeated structure in opaque text or binary payloads through generic pooling rather than ad hoc parsing shortcuts.
- The stream boundary remains non-blocking and rejects unsupported sensory ingress at startup.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter7.conformance
```

This suite is expected to fail when:

- Unsupported sensory organs, surfaces, or transports bypass the perimeter contract.
- Repository parsing becomes non-deterministic or stops projecting typed topology.
- Telemetry ingestion regresses into untyped event handling or skips the Rhizome projection boundary.
- Unknown payload discovery collapses back into raw quantization without pooled structural abstractions.
- Listener startup stops rejecting invalid subscriptions and allows unsupported ingest surfaces.

The GitHub Actions workflow `chapter7-conformance.yml` must pass on pushes and pull requests.

---

# Chapter 8 Conformance

This document captures the Chapter 8 action gate for:

- `docs/src/content/docs/part-4/chapter-8/1-introduction.md`
- `docs/src/content/docs/part-4/chapter-8/2-linguistic-motor-cells.md`
- `docs/src/content/docs/part-4/chapter-8/3-the-sandbox.md`
- `docs/src/content/docs/part-4/chapter-8/4-friction-mirror-neurons.md`
- `docs/src/content/docs/part-4/chapter-8/5-chapter-wrap-up.md`

Chapter 8 conformance requires these behaviors:

- Planning crosses the action membrane through a typed execution-intent contract.
- Human-facing status output is rendered by a bounded operator-language surface rather than free-form generation.
- Irreversible sandbox action is gated by WRS, isolated in the Firecracker membrane, and returned with audit plus telemetry artifacts.
- Operator friction and approval events affect only socio-linguistic template pathways and cannot target protected architectural domains.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter8.conformance
```

This suite is expected to fail when:

- Plans dispatch raw action maps instead of validated execution intents.
- Operator-facing output stops carrying deterministic template identity and bounded phrasing.
- Sandbox execution bypasses WRS, loses audit provenance, or stops returning telemetry.
- Dashboard or core feedback capture can mutate protected planning, execution, or sandbox-policy domains.

The GitHub Actions workflow `chapter8-conformance.yml` must pass on pushes and pull requests.

---

# Chapter 9 Conformance

This document captures the Chapter 9 drive gate for:

- `docs/src/content/docs/part-5/chapter-9/1-introduction.md`
- `docs/src/content/docs/part-5/chapter-9/2-the-atp-analogue.md`
- `docs/src/content/docs/part-5/chapter-9/3-epistemic-foraging-curiosity.md`
- `docs/src/content/docs/part-5/chapter-9/4-the-simulation-daemon-dreams.md`
- `docs/src/content/docs/part-5/chapter-9/5-chapter-wrap-up.md`

Chapter 9 conformance requires these behaviors:

- ATP scarcity changes real admission and scheduling outcomes across spawn, planning, execution, and sandbox routing.
- Idle curiosity probes only low-confidence candidates and only through the sandbox membrane.
- Dream-state permutations replay historical execution outcomes through isolated `execute_plan` intents and persist simulation results back into Rhizome.
- The drive surface stays coherent across metabolism policy, curiosity, and dreaming instead of drifting into disconnected subsystems.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter9.conformance
```

This suite is expected to fail when:

- ATP pressure stops affecting real spawn, plan, execution, or sandbox admission outcomes.
- Curiosity probes run while the organism is not idle, or bypass typed sandbox execution.
- Dream-state permutations stop sourcing historical execution outcomes or stop projecting simulation events into Rhizome.
- The Rhizome memory contract no longer exposes the bounded low-confidence, recent-outcome, or simulation-event surfaces required by Chapter 9.

The GitHub Actions workflow `chapter9-conformance.yml` must pass on pushes and pull requests.

---

# Chapter 10 Conformance

This document captures the Chapter 10 sovereignty gate for:

- `docs/src/content/docs/part-5/chapter-10/1-introduction.md`
- `docs/src/content/docs/part-5/chapter-10/2-sovereign-directives.md`
- `docs/src/content/docs/part-5/chapter-10/3-defiance-and-homeostasis.md`
- `docs/src/content/docs/part-5/chapter-10/4-the-cross-workspace-architect.md`
- `docs/src/content/docs/part-5/chapter-10/5-chapter-wrap-up.md`

Chapter 10 conformance requires these behaviors:

- Sovereignty exists as an explicit runtime control plane, not an implicit planner hint.
- Persistent objective manifests change attractor ranking and generate localized `.nexical/plan.yml` blueprints.
- Refusal and negotiation decisions are explicit, bounded, and persisted when sovereign law or homeostasis conflict with an intent.
- Cross-workspace planning coordinates a central architect workspace with localized execution limbs through shared memory, not through a monolithic global state machine.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter10.conformance
```

This suite is expected to fail when:

- Sovereign directives stop flowing into metabolism, planning, or objective weighting.
- Objective manifests stop changing attractor ranking or stop producing localized workspace blueprints.
- Mutation intents can bypass paradox detection, refusal, or negotiation reporting.
- Cross-workspace coordination stops writing localized plans or stops persisting shared-memory workspace coordination.

The GitHub Actions workflow `chapter10-conformance.yml` must pass on pushes and pull requests.

---

# Chapter 11 Conformance

This document captures the Chapter 11 genesis gate for:

- `docs/src/content/docs/part-6/chapter-11/1-introduction.md`
- `docs/src/content/docs/part-6/chapter-11/2-the-monorepo-pipeline.md`
- `docs/src/content/docs/part-6/chapter-11/3-visualizing-the-rhizome.md`
- `docs/src/content/docs/part-6/chapter-11/4-the-distributed-experience-engram.md`
- `docs/src/content/docs/part-6/chapter-11/5-chapter-wrap-up.md`

Chapter 11 conformance requires these behaviors:

- Operational maturity exists as an explicit contract with build, deploy, observe, and distribute evidence.
- The engine workspace remains read-only while localized target workspaces carry execution plans and mutation work.
- Engrams are portable, selective, compatibility-checked memory products rather than opaque full-state dumps.
- Dashboard observability reflects real Rhizome topology, temporal archive state, active cells, and sovereignty priorities.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter11.conformance
```

This suite is expected to fail when:

- Operational maturity stops surfacing blockers or stops exposing release evidence.
- The monorepo pipeline allows execution work to target the engine workspace directly.
- Engrams stop supporting selective capture, compatibility validation, or partial hydration.
- The dashboard drifts back to metabolic-only snapshots and stops exposing organism observability.

The GitHub Actions workflow `chapter11-conformance.yml` must pass on pushes and pull requests.

---

# Chapter 12 Conformance

This document captures the Chapter 12 maturation gate for:

- `docs/src/content/docs/part-6/chapter-12/1-introduction.md`
- `docs/src/content/docs/part-6/chapter-12/2-the-baseline-diet.md`
- `docs/src/content/docs/part-6/chapter-12/3-execution-telemetry.md`
- `docs/src/content/docs/part-6/chapter-12/4-the-synthetic-oracle-curriculum-the-teacher-daemon.md`
- `docs/src/content/docs/part-6/chapter-12/5-abstract-intent.md`
- `docs/src/content/docs/part-6/chapter-12/6-chapter-wrap-up.md`

Chapter 12 conformance requires these behaviors:

- Maturation exists as an explicit lifecycle contract instead of ad hoc curriculum logic.
- Baseline diet intake establishes deterministic structural grammar and persists curriculum evidence.
- Execution telemetry is standardized, replayable, and reusable as training input.
- The teacher daemon generates bounded exams from real documentation or specs, routes them through sandbox execution, and persists the resulting curriculum evidence.
- Abstract intent ingests documentation plus git history, then persists implementation drift as a queryable memory surface.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter12.conformance
```

This suite is expected to fail when:

- The maturation lifecycle stops exposing blockers, evidence, or next-phase links.
- Baseline intake stops rejecting weak structural input or stops persisting accepted curriculum artifacts.
- Execution telemetry stops emitting replayable curriculum records.
- Teacher-daemon exams stop flowing through the sandbox membrane or stop persisting teacher events.
- Abstract intent stops emitting implementation-drift records from documentation and history evidence.

The GitHub Actions workflow `chapter12-conformance.yml` must pass on pushes and pull requests.

---

This book is the contributor-facing companion to the architecture corpus. It is intentionally small for now, because much of the underlying source material still lives in repository documents that have not yet been fully normalized into the public docs surface.

Use this book as the current entry point into the implementation-facing contracts, subsystem boundaries, and regression gates that keep the organism aligned with its architecture.

    Start with the implementation contracts and subsystem boundaries. [Open NIF Safety](/docs/developer/nif-safety/)

    Follow the maturation and operational guidance for building inside the platform. [Open Operational Maturity](/docs/developer/operational-maturity/)

    Use the chapter gates as regression boundaries when changing behavior. [Open Chapter 1 Conformance](/docs/developer/chapter-1-conformance/)

## What this book covers today

- Core references for NIF safety, subsystem contracts, learning loops, monorepo execution, and lifecycle maturity.
- Chapter-by-chapter conformance references that turn architecture claims into concrete regression boundaries.
- Contributor-facing material that should be read alongside the architecture book and the repository source.

---

# Learning Loop Contract

This document captures the explicit learning loop introduced for:

- `docs/src/content/docs/part-3/chapter-6/1-introduction.md`

The learning loop is now modeled as five ordered phases:

1. `perception`
2. `action_feedback`
3. `prediction_error`
4. `plasticity`
5. `consolidation`

The current implementation binds those phases across the organism like this:

- `Core.StemCell` forms expectations and drives action execution.
- `Rhizome.Memory` persists action outcomes and prediction errors into durable memory.
- `NervousSystem.PainReceptor` emits typed nociception for structural failure.
- `Core.StemCell` prunes or reinforces Rhizome pathways based on prediction error or success.
- `Rhizome.ConsolidationManager` bridges working memory into the archive and performs the sleep-cycle consolidation pass.

Local validation commands:

```bash
cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/learning_loop_contract_test.exs test/core/stem_cell_test.exs
cd /home/adrian/Projects/nexical/karyon/app/nervous_system && mix test test/nervous_system/pain_receptor_test.exs
cd /home/adrian/Projects/nexical/karyon/app/rhizome && mix test test/rhizome/consolidation_manager_test.exs
```

---

# Chapter 12 Maturation Lifecycle

`Core.MaturationLifecycle` is the canonical Chapter 12 introduction contract.

It defines four explicit maturation phases:

- `baseline_diet`: deterministic structural curriculum from baseline artifacts and sensory parsing.
- `execution_telemetry`: replayable execution evidence grounded in the learning loop and service-backed storage.
- `synthetic_oracle`: teacher-guided refinement and synthetic exam generation.
- `intent_drift`: correction of divergence between sovereign intent, evolving needs, values, and runtime behavior.

Local validation:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix compile
cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/maturation_lifecycle_test.exs
```

This contract is intentionally ahead of the current implementation. Later Chapter 12 phases should satisfy its blockers by adding:

- real baseline diet ingestion and acceptance criteria
- telemetry replay and curriculum tagging
- teacher-daemon and synthetic oracle generation
- intent-drift detection and correction tied to objective manifests and Rhizome memory

---

# Chapter 11 Monorepo Pipeline

`Core.MonorepoPipeline` is the canonical engine-versus-target-workspace contract.

Rules:

- The repository root is the engine workspace and is treated as read-only control plane state.
- Localized execution limbs must live outside the engine tree.
- `.nexical/plan.yml` blueprints are only emitted into validated target workspaces.
- `Sandbox.WRS` refuses `execute_plan` intents that omit a target workspace or point back at the engine tree.
- Firecracker execution manifests now record both the engine manifest and the validated target workspace root.

Validation entry points:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix compile
cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/monorepo_pipeline_test.exs test/core/objective_manifest_test.exs
cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/wrs_test.exs test/sandbox/executor_test.exs test/sandbox/provisioner_test.exs
```

---

# Developer Endpoints & NIF Safety

Developing native Organelles for Karyon requires strict adherence to memory safety and BEAM scheduler sympathy.

## FFI Architecture

Karyon uses `Rustler` for FFI. The goal is to maximize performance without compromising the stability of the Erlang VM.

### Resource Objects

All persistent native state must be wrapped in `ResourceArc`.

- **Safety**: Resource Objects are trackable by the BEAM Garbage Collector.
- **Implementation**: See `app/rhizome/native/rhizome_nif/src/resource.rs`.

### Cache Alignment & NUMA

Native structs for the Rhizome must be cache-aligned to prevent false sharing and NUMA bus bottlenecks.

```rust
#[repr(C)]
#[repr(align(64))]
pub struct GraphPointer { ... }
```

## Scheduler Sympathy

### Dirty Schedulers

Any operation taking longer than 1ms (I/O, heavy math, graph traversals) MUST use a Dirty Scheduler.

- **DirtyIo**: For database calls (Memgraph, XTDB).
- **DirtyCpu**: For compute-heavy algorithms (Louvain, Tree-sitter parsing).

```elixir
#[rustler::nif(schedule = "DirtyIo")]
pub fn native_operation() { ... }
```

## Integrating New Organelles

To add a new native capability (e.g., a new Tree-sitter language):

1. **Cargo.toml**: Add the grammar dependency.
2. **lib.rs**: Export the language function in the `sensory_nif`.
3. **native.ex**: Update the Elixir bridge signature.
4. **Makefile**: Ensure the `build` target includes the new application directory.

## Known Constraints

- **Zero-Copy**: Favor sub-binary references for large code strings to avoid FFI serialization overhead.
- **Memory Leaks**: Always run `make test-native` under Valgrind after significant NIF changes.

---

# Chapter 11 Operational Maturity

`Core.OperationalMaturity` is the canonical Chapter 11 introduction contract.

It defines four explicit targets:

- `build`: sterile engine boot evidence, preflight status, and release environment.
- `deploy`: dependency readiness and admission posture for runnable releases.
- `observe`: bounded operator visibility through the existing health and operator-output surface.
- `distribute`: persistent objective ingestion and cross-workspace blueprint readiness.

Validation entry points:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix compile
cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/operational_maturity_test.exs test/core/service_health_test.exs
cd /home/adrian/Projects/nexical/karyon/app/dashboard && env PATH=/tmp/protoc/bin:$PATH mix test test/dashboard_web/controllers/health_controller_test.exs
```

This contract is introductory on purpose. Later Chapter 11 and 12 phases should extend the evidence behind each target instead of inventing parallel maturity models.

---

# Subsystem Contracts

This document captures the subsystem ownership model required by Part II Chapter 3 Section 1 of the Karyon book source at `docs/src/content/docs/part-2/chapter-3/1-introduction.md`.

## Ownership

- `core` is the nucleus and cytoplasm boundary.

  It owns sterile planning contracts, actor lifecycle, DNA transcription, BEAM process-group boot, and metabolic coordination.

- `rhizome` is the memory and organelle boundary.

  It owns Rustler-backed graph and temporal memory operations, consolidation, optimization, and XTDB/Memgraph interfaces.

- `sandbox` is the membrane boundary.

  It owns Firecracker embodiment, VM provisioning, VMM supervision, and host isolation mechanics.

- `nervous_system` is the nervous-system boundary.

  It owns synaptic transport, endocrine signals, and nociception routing.

- `dashboard` is observability only.

  It must not take ownership of planning, memory mutation, or Firecracker embodiment.

## Boundary Rules

- The nucleus must not own Firecracker, dashboard routing, or direct memory-engine implementation details.
- The membrane must not own planning, graph-memory mutation logic, or dashboard responsibilities.
- The nervous system must not own planner logic or memory-optimizer logic.
- Organelles must stay behind Rhizome boundaries and must not absorb sandbox or dashboard behavior.

## Enforcement

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix subsystem.contracts
```

The umbrella test `app/test/subsystem_contracts_test.exs` is the executable contract for this section.
