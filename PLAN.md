# Karyon Book-Indexed Architectural Parity Program

This file is the source of truth for bringing the implementation in `app/` into exact architectural alignment with the Karyon manifesto and theory documented in the book source.

## Canonical Sources

Source precedence for this program:

1. `docs/src/content/docs/**` as the canonical book source because `docs/public/book.md` is not present in the repository.
2. [`AGENTS.md`](/home/adrian/Projects/nexical/karyon/AGENTS.md) as governing project instructions.
3. [`SPEC.md`](/home/adrian/Projects/nexical/karyon/SPEC.md) as structural and operational specification.

All parity work must be evaluated against the book first, while explicitly logging any conflict between the book and governing repo instructions. Where a conflict has already been resolved in this file, implementation must follow the resolved contract.

## Conflict Ledger

These conflicts are known at the start of this program and must remain visible until resolved or explicitly accepted:

1. `virtio-fs` and DAX guidance conflict.
   Book position:
   `docs/src/content/docs/part-2/chapter-3/5-the-kvm-qemu-membrane.md`, `docs/src/content/docs/part-4/chapter-8/3-the-sandbox.md`, and related wrap-up sections repeatedly favor `virtio-fs` bridging and discuss DAX as part of the membrane model.
   Governing repo position:
   [`AGENTS.md`](/home/adrian/Projects/nexical/karyon/AGENTS.md) and `GEMINI.md` require avoiding `virtio-fs` DAX in active workspaces and prefer `virtio-blk` plus overlay filesystems for I/O isolation and performance.
   Resolution:
   The implementation contract for active Firecracker workspaces is `virtio-blk` plus overlay-backed writable workspaces, not `virtio-fs`.
   Rationale:
   The current sandbox code already attaches block drives and does not implement a real `virtio-fs` share, while repo governance explicitly prefers `virtio-blk` plus overlay filesystems over `virtio-fs` DAX for active workspaces.
   Remaining work:
   Complete the block-backed workspace model, remove stale `virtio-fs` assumptions from code and docs, and document the divergence from the book language where necessary.

## Gap-Analysis Method

Each section phase in this file follows the same structure:

- `Book Claim`: the architectural or theoretical behavior required by the corresponding section.
- `Observed Code Reality`: what the current implementation in `app/` actually does today.
- `Gap`: the concrete mismatch between the book and the implementation.
- `Implementation Tasks`: the work required to close the gap without violating organism constraints.
- `Validation`: the minimum commands or suites required to verify the phase.
- `Exit Criteria`: the condition that must be true before the phase can be marked complete.

Status model for execution:

- `[todo]` not started
- `[doing]` in progress
- `[blocked]` blocked by conflict, missing dependency, or unresolved design issue
- `[done]` implemented and validated

Global parity themes already observed and expected to recur through the phases:

- `core` still relies on stringly motor dispatch, direct Cypher construction, and placeholder planning shortcuts instead of typed planning-cell contracts.
- `sensory` still contains demo-level polling and quantization behavior rather than the deterministic multi-organ sensory perimeter described by the book.
- `sandbox` provisions Firecracker, but the workspace bridge, WRS gate, and plan-driven mutation loop are incomplete relative to the book.
- `dashboard` exposes runtime health but not the Rhizome and topology observability required by the book.
- `~/.karyon/objectives/`, localized `.nexical/plan.yml`, cross-workspace planning, teacher-daemon curriculum, and negotiation or defiance surfaces are missing.
- surprise is still represented by a hardcoded variational free energy calculation rather than a typed model combining expectations, precision, outcome telemetry, and weighted priors derived from needs and values.
- objectives, needs, and values are not yet represented as weighted priors that can measurably alter attractor selection, improvement priorities, pruning, reinforcement, and refusal behavior.

## Global Validation Baseline

Default validation commands for parity work:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix compile
```

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix test
```

Subsystem suites:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/nervous_system/test
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sandbox/test
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/dashboard/test
```

Service-backed parity phases must add the relevant integration command or manual verification for Memgraph, XTDB, NATS, and Firecracker.

## Part I Milestone

Milestone condition:
Every Chapter 1 and Chapter 2 phase is `[done]`, chapter wrap-up conformance tests exist, and the app no longer depends on monolithic, stateless, or purely prompt-response assumptions for its core reasoning loop.

## C01-S01 [todo] Chapter 1 / Section 1

**Source**
`docs/src/content/docs/part-1/chapter-1/1-introduction.md`

**Book Claim**
Karyon must replace monolithic, static, stateless AI behavior with a sovereign active-inference organism grounded in continuous state and topological memory.

**Observed Code Reality**
The umbrella structure matches the intended subsystem split, but the implementation still contains direct request-response flows and local shortcut logic that do not yet prove a closed active-inference loop.

**Gap**
There is no explicit executable parity rubric defining what counts as monolithic, stateless, or non-topological behavior across the app boundary.

**Implementation Tasks**
- Create a book-parity rubric module or test support package that defines forbidden monolithic or stateless patterns.
- Add architecture conformance tests that assert stateful graph-backed operation for planning, memory, and execution paths.
- Audit umbrella app boundaries for direct prompt-response style control flow and catalog all violations.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix compile`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
An explicit parity rubric exists and failing tests catch monolithic or stateless regressions at the app boundary.

## C01-S02 [todo] Chapter 1 / Section 2

**Source**
`docs/src/content/docs/part-1/chapter-1/2-the-statistical-dead-end.md`

**Book Claim**
The organism must not behave like a prompt-conditioned autocomplete engine. Planning and action should emerge from graph-backed state transitions rather than localized text-driven responses.

**Observed Code Reality**
`Core.MotorDriver` and `Core.StemCell` still use direct graph queries, stringly step generation, and immediate execution dispatch patterns.

**Gap**
Planning is not yet expressed as a typed, graph-native state transition system with explicit attractor and delta semantics.

**Implementation Tasks**
- Introduce typed planning contracts for attractors, graph steps, and execution deltas.
- Remove remaining prompt-response style orchestration shortcuts from core planning paths.
- Persist planning transitions as first-class graph entities instead of transient local maps.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/motor_driver_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/stem_cell_test.exs`

**Exit Criteria**
Core planning is graph-backed and typed, and direct request-response planning shortcuts are removed from runtime behavior.

## C01-S03 [todo] Chapter 1 / Section 3

**Source**
`docs/src/content/docs/part-1/chapter-1/3-catastrophic-forgetting-hardware-economics.md`

**Book Claim**
The system must support durable local memory and hardware-aware operation rather than relying on ephemeral context or brute-force scale.

**Observed Code Reality**
Belief hydration exists through XTDB, and metabolism exists through `Core.MetabolicDaemon`, but durable recovery and hardware-driven execution budgeting remain incomplete and uneven across subsystems.

**Gap**
There is no unified durable memory and hardware-economics contract that forces all key loops to operate with bounded context and explicit resource budgets.

**Implementation Tasks**
- Standardize durable belief recovery for cells and planning state.
- Tie execution admission and scheduling to metabolic resource budgets.
- Add bounded-context recovery tests across core, rhizome, and sandbox edges.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/state_recovery_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/metabolic_stress_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test`

**Exit Criteria**
Durable recovery and hardware-budget enforcement are explicit and validated across the main cognitive loop.

## C01-S04 [todo] Chapter 1 / Section 4

**Source**
`docs/src/content/docs/part-1/chapter-1/4-the-predictive-coding-failure.md`

**Book Claim**
Adaptation must be driven by prediction error and structural graph update, not by ad hoc output handling.

**Observed Code Reality**
Prediction errors are emitted, but adaptation paths still include direct query mutation, placeholder edge weakening, and partial local handling that bypass a unified learning contract.

**Gap**
Prediction-error ingestion is not yet the single authoritative path for structural correction, and the current surprise path still depends on a hardcoded variational free energy calculation instead of a typed model grounded in expectations, precision, and observed outcomes.

**Implementation Tasks**
- Define a typed prediction-error ingestion pipeline from nervous system to rhizome update.
- Replace the hardcoded variational free energy function with a typed surprise model that explicitly combines expectation precision, observed failure or success telemetry, and weighted priors from active objectives.
- Remove ad hoc mutation branches that bypass the prediction-error path.
- Ensure execution failures, compiler failures, and sensory contradictions all land in the same learning loop.
- Persist surprise inputs and outputs so the computed free energy can be audited, replayed, and compared across runs.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/nervous_system/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/recovery_chaos_integration_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/stem_cell_test.exs`

**Exit Criteria**
Prediction error becomes the sole authoritative trigger for structural adaptation, and surprise is computed through a typed variational free energy model rather than a hardcoded placeholder.

## C01-S05 [todo] Chapter 1 / Section 5

**Source**
`docs/src/content/docs/part-1/chapter-1/5-chapter-wrap-up.md`

**Book Claim**
The chapter’s rejection of transformer-like assumptions must remain enforceable as the system evolves.

**Observed Code Reality**
No chapter-level conformance suite exists.

**Gap**
Regression can reintroduce monolithic or stateless behavior without a dedicated guardrail.

**Implementation Tasks**
- Add Chapter 1 conformance tests.
- Document forbidden architectural regressions derived from Chapter 1.
- Require Chapter 1 tests in CI for affected apps.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test`

**Exit Criteria**
Chapter 1 parity is executable and fails closed on regression.

## C02-S01 [todo] Chapter 2 / Section 1

**Source**
`docs/src/content/docs/part-1/chapter-2/1-introduction.md`

**Book Claim**
The organism’s biology-first principles must be encoded as concrete runtime invariants.

**Observed Code Reality**
The codebase uses biological naming and subsystem mapping, but those invariants are not codified as shared executable rules across apps.

**Gap**
Biology-first architecture is descriptive rather than enforceable.

**Implementation Tasks**
- Add shared architecture invariants for biology-first behavior.
- Expose those invariants to core, nervous system, rhizome, sandbox, and sensory tests.
- Fail if shared-state, centralized-lock, or synchronous bottleneck patterns are introduced.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test`

**Exit Criteria**
Biology-first rules are expressed as common executable invariants across the umbrella.

## C02-S02 [todo] Chapter 2 / Section 2

**Source**
`docs/src/content/docs/part-1/chapter-2/2-the-cellular-state-machine.md`

**Book Claim**
The core runtime must be a cellular actor system with decentralized discovery and without central coordination bottlenecks.

**Observed Code Reality**
`Core.EpigeneticSupervisor`, `Core.StemCell`, and `:pg` routing exist, but differentiation and discovery remain simplistic and some paths still depend on named global processes.

**Gap**
The actor model exists structurally but not yet with the full decentralization and anti-bottleneck rigor described by the book.

**Implementation Tasks**
- Reduce dependency on globally named processes where decentralized discovery is more appropriate.
- Formalize role groups and routing contracts through `:pg` and local message passing.
- Add stress tests for spawn, routing, and apoptosis under high churn.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/stem_cell_property_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/epigenetic_supervisor_stress_test.exs`

**Exit Criteria**
Discovery and coordination are decentralized and validated under load.

## C02-S03 [todo] Chapter 2 / Section 3

**Source**
`docs/src/content/docs/part-1/chapter-2/3-predictive-processing.md`

**Book Claim**
Predictive processing requires immediate surprise propagation, expectation management, and pain delivery as a closed loop.

**Observed Code Reality**
`NervousSystem.PainReceptor` and expectation handling exist, but telemetry attachment, metadata handling, and feedback propagation remain partial and inconsistent.

**Gap**
The closed loop from expectation to surprise to structural response is incomplete, and the expectation model does not yet encode how active objectives and values bias surprise calculation.

**Implementation Tasks**
- Harden `PainReceptor` recursion avoidance and event capture semantics.
- Make expectations typed and traceable through execution and nociception.
- Define how expectation precision and active objective weights contribute to variational free energy.
- Persist prediction-error lineage into Rhizome for later consolidation.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/nervous_system/test/nervous_system/pain_receptor_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/stem_cell_test.exs`

**Exit Criteria**
Expectation formation, weighted surprise, and structural response form one reliable loop.

## C02-S04 [todo] Chapter 2 / Section 4

**Source**
`docs/src/content/docs/part-1/chapter-2/4-abstract-state-prediction.md`

**Book Claim**
The organism must predict abstract structural states rather than literal token or string outputs.

**Observed Code Reality**
Planning and memory paths still rely on stringly IDs, direct Cypher, and implicit local maps.

**Gap**
Abstract state prediction is not represented by explicit typed contracts, and attractor states are not yet linked to weighted needs or values that can drive improvement selection.

**Implementation Tasks**
- Define typed abstract-state, expectation, and predicted-outcome schemas.
- Define attractor-state schemas that include weighted needs, values, and objective priors.
- Replace string-concatenated planning assumptions with structured state transitions.
- Ensure sensory and execution telemetry project into abstract-state entities, not raw ad hoc strings.
- Require planning to consume weighted attractors rather than flat goals.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/motor_driver_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test`

**Exit Criteria**
Predictions and plans are modeled as typed abstract states across the loop, and attractors carry weighted priors that can drive improvement selection.

## C02-S05 [todo] Chapter 2 / Section 5

**Source**
`docs/src/content/docs/part-1/chapter-2/5-continuous-local-plasticity.md`

**Book Claim**
Learning must be local, forward-only, and structurally specific, with safe strengthening and pruning semantics.

**Observed Code Reality**
Local pruning exists only as placeholder `create_pointer` and `weaken_edge` behavior keyed by synthetic IDs.

**Gap**
Plasticity is not yet grounded in real graph edges, typed local pathways, or explicit strengthen versus prune semantics.

**Implementation Tasks**
- Replace synthetic pointer-based weakening with real edge selection and mutation semantics.
- Add strengthening paths for successful execution and perception reinforcement.
- Enforce forward-only local plasticity and prohibit global retraining-style shortcuts.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/rhizome/optimizer_complex_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/native_test.exs`

**Exit Criteria**
Plasticity operates on real local pathways with validated strengthen and prune behavior.

## C02-S06 [todo] Chapter 2 / Section 6

**Source**
`docs/src/content/docs/part-1/chapter-2/6-chapter-wrap-up.md`

**Book Claim**
The biological shift must survive integration and regression.

**Observed Code Reality**
No chapter-level biological-shift conformance suite exists.

**Gap**
Forward-only local learning and actor-style cognition can regress silently.

**Implementation Tasks**
- Add Chapter 2 conformance tests for actor isolation, predictive processing, abstract-state prediction, and local plasticity.
- Wire these tests into parity CI.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test`

**Exit Criteria**
Chapter 2 biology-first behavior is enforced continuously by tests.

## Part II Milestone

Milestone condition:
All Chapter 3 and Chapter 4 phases are `[done]`, subsystem boundaries are explicit, membrane behavior is documented against the conflict ledger, and cell lifecycle behavior is governed by validated DNA and epigenetic rules.

## C03-S01 [todo] Chapter 3 / Section 1

**Source**
`docs/src/content/docs/part-2/chapter-3/1-introduction.md`

**Book Claim**
The physical organism must consist of a sterile nucleus, BEAM cytoplasm, Rust organelles, a hard membrane, and a nervous system.

**Observed Code Reality**
The umbrella app split broadly matches the book, but interfaces and responsibilities remain only partially explicit and are not defended by subsystem contracts.

**Gap**
Subsystem boundaries are conceptually present but not fully formalized.

**Implementation Tasks**
- Define subsystem contracts for nucleus, cytoplasm, organelles, membrane, and nervous system.
- Add contract tests proving the intended ownership boundaries.
- Document which runtime responsibilities are permitted in each app.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix compile`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test`

**Exit Criteria**
Subsystem boundaries are explicit, documented, and test-backed.

## C03-S02 [todo] Chapter 3 / Section 2

**Source**
`docs/src/content/docs/part-2/chapter-3/2-the-microkernel-philosophy.md`

**Book Claim**
The microkernel core must remain mechanically powerful but topologically sterile and free of business or domain logic.

**Observed Code Reality**
Core modules still contain project-specific behavior and direct operational assumptions that should live in DNA, Rhizome, or explicit edge modules.

**Gap**
Sterility is not consistently preserved in `app/core`.

**Implementation Tasks**
- Audit `app/core/lib/core/**` for embedded project semantics and move them into DNA, Rhizome state, or bounded adapters.
- Convert direct executors and action policies into declarative or graph-derived forms.
- Add tests preventing future leakage of domain-specific logic into sterile modules.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
Core is reduced to orchestration, safety, and lifecycle mechanics with no hidden business logic.

## C03-S03 [todo] Chapter 3 / Section 3

**Source**
`docs/src/content/docs/part-2/chapter-3/3-erlang-beam-cytoplasm.md`

**Book Claim**
The BEAM layer must provide crash-only, scalable, lock-free cellular concurrency and routing.

**Observed Code Reality**
OTP supervision exists and some scale or chaos tests exist, but large-scale routing and failure semantics are not yet proven end to end.

**Gap**
The BEAM cytoplasm is scaffolded but not yet verified as the exact organism substrate the book describes.

**Implementation Tasks**
- Extend supervision and recovery tests for high churn and localized failure.
- Audit for synchronous bottlenecks and centralized chokepoints.
- Add scale validation for process-group routing and message flow.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/tier5_global_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/chaos/resilience_test.exs`

**Exit Criteria**
BEAM-scale concurrency and crash-only recovery are validated as core runtime guarantees.

## C03-S04 [todo] Chapter 3 / Section 4

**Source**
`docs/src/content/docs/part-2/chapter-3/4-rust-nifs-organelles.md`

**Book Claim**
Rust organelles must offload heavy work safely using dirty schedulers, explicit contracts, and safe memory boundaries.

**Observed Code Reality**
NIF crates exist for metabolism, rhizome, and sensory behavior, but dirty-scheduler usage, zero-copy assumptions, and panic containment are not yet comprehensively audited.

**Gap**
NIF safety and contract discipline are incomplete relative to the book.

**Implementation Tasks**
- Audit all Rust NIF exports for dirty-scheduler suitability.
- Add explicit error and panic containment across the Elixir boundary.
- Verify memory ownership and zero-copy assumptions where applicable.
- Add contract tests for all cross-language interfaces.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/native_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/rhizome/nif_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test/sensory/nif_test.exs`

**Exit Criteria**
All organelle boundaries are explicit, typed, and safe under stress.

## C03-S05 [todo] Chapter 3 / Section 5

**Source**
`docs/src/content/docs/part-2/chapter-3/5-the-kvm-qemu-membrane.md`

**Book Claim**
All action must cross a hardware-isolated membrane backed by microVM execution and an explicit workspace bridge.

**Observed Code Reality**
Sandbox modules provision Firecracker and enforce helper-based networking, but workspace bridging, plan-driven execution, and the storage bridge contract remain incomplete.

**Gap**
The membrane exists operationally only in part, and the resolved `virtio-blk` plus overlay workspace model is not yet fully implemented end to end.

**Implementation Tasks**
- Document the resolved membrane bridge contract: immutable base rootfs plus `virtio-blk` plus overlay-backed writable workspace for each Firecracker VM.
- Remove or rewrite stale `virtio-fs` assumptions in sandbox code comments, docs, and tests.
- Implement mounted workspace policy and execution bridge semantics on top of the block-backed workspace model.
- Implement the per-VM writable workspace lifecycle, including creation, attachment, isolation, and teardown.
- Ensure all mutation or compile paths go through the membrane and never touch host state directly.
- Add end-to-end membrane tests for boot, bridge, isolation, telemetry, and teardown.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sandbox/test`
- Firecracker-backed sandbox smoke validation in a host environment with real kernel and rootfs assets.

**Exit Criteria**
All action crosses the membrane by policy and by verified runtime behavior using the resolved `virtio-blk` plus overlay workspace contract.

## C03-S06 [todo] Chapter 3 / Section 6

**Source**
`docs/src/content/docs/part-2/chapter-3/6-the-nervous-system.md`

**Book Claim**
The nervous system must separate peer-to-peer signaling and global control-plane signaling with strict backpressure and low-latency rules.

**Observed Code Reality**
ZeroMQ synapses and NATS endocrine signaling exist, but role separation, buffer semantics, and telemetry around pressure and failure remain incomplete.

**Gap**
The nervous system exists, but not yet as a fully validated dual-plane signaling architecture.

**Implementation Tasks**
- Finalize transport role separation between ZeroMQ and NATS.
- Enforce zero-buffer or bounded-buffer semantics consistently.
- Add transport telemetry for backpressure, retries, and degraded modes.
- Validate message contracts through protobuf or typed schemas end to end.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/nervous_system/test`

**Exit Criteria**
The nervous system behaves as a validated dual-plane signaling fabric under load and failure.

## C03-S07 [todo] Chapter 3 / Section 7

**Source**
`docs/src/content/docs/part-2/chapter-3/7-chapter-wrap-up.md`

**Book Claim**
Physical synthesis across the organism layers must remain coherent.

**Observed Code Reality**
Cross-app contract tests are still sparse relative to the density of the interfaces.

**Gap**
Subsystem integration can drift without chapter-level physical synthesis checks.

**Implementation Tasks**
- Add cross-app runtime contract tests for core, sandbox, nervous system, and rhizome.
- Enforce membrane and signaling expectations in CI.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test`

**Exit Criteria**
Chapter 3 physical synthesis is guarded by cross-app contract validation.

## C04-S01 [todo] Chapter 4 / Section 1

**Source**
`docs/src/content/docs/part-2/chapter-4/1-introduction.md`

**Book Claim**
DNA and epigenetics define the organism’s control plane for role, policy, and lifecycle.

**Observed Code Reality**
DNA files exist, but their schema and relationship to differentiation and supervision are informal.

**Gap**
The control plane is not yet explicit or strongly validated.

**Implementation Tasks**
- Define the control-plane model linking DNA, differentiation, metabolism, and apoptosis.
- Add schema ownership and validation rules for all DNA assets.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
DNA and epigenetic control boundaries are explicit and test-backed.

## C04-S02 [todo] Chapter 4 / Section 2

**Source**
`docs/src/content/docs/part-2/chapter-4/2-declarative-genetics.md`

**Book Claim**
Cell behavior must be described declaratively through structured DNA rather than embedded logic.

**Observed Code Reality**
YAML DNA is used, but schema rigor, inheritance, validation, and allowed-action policy are incomplete.

**Gap**
DNA remains partially declarative and partially ad hoc.

**Implementation Tasks**
- Define and validate DNA schema versions, inheritance, defaults, and allowed-actions semantics.
- Prevent startup when DNA violates required policy.
- Centralize DNA parsing and validation failures into testable error flows.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/preflight_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/tier1_cellular_test.exs`

**Exit Criteria**
DNA is authoritative, validated, and sufficient to govern cell behavior without embedded policy leakage.

## C04-S03 [todo] Chapter 4 / Section 3

**Source**
`docs/src/content/docs/part-2/chapter-4/3-the-epigenetic-supervisor.md`

**Book Claim**
The epigenetic supervisor must transcribe DNA into differentiated cells based on environmental pressure.

**Observed Code Reality**
`Core.EpigeneticSupervisor` only gates spawning on coarse metabolic pressure and starts generic `Core.StemCell` children.

**Gap**
Differentiation and environmental transcription are too simplistic.

**Implementation Tasks**
- Expand the supervisor to choose differentiated roles based on environmental and graph context.
- Allow dynamic transcription of DNA variants into specialized cells.
- Persist differentiation decisions and outcomes into Rhizome.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/epigenetic_supervision_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/epigenetic_supervisor_stress_test.exs`

**Exit Criteria**
Cells are differentiated through validated environmental transcription rather than uniform spawning.

## C04-S04 [todo] Chapter 4 / Section 4

**Source**
`docs/src/content/docs/part-2/chapter-4/4-apoptosis-digital-torpor.md`

**Book Claim**
The organism must shed cells, enter torpor, and preserve homeostasis based on metabolic survival calculus.

**Observed Code Reality**
`Core.MetabolicDaemon` and `Core.StemCell` perform targeted apoptosis and torpor-like behavior, but revival policy, scope, and semantics are incomplete.

**Gap**
Apoptosis and torpor exist, but not as a formalized lifecycle contract.

**Implementation Tasks**
- Define lifecycle states for active, torpor, shed, revived, and terminated cells.
- Add selective pruning and recovery policy by cell role and pressure class.
- Ensure torpor preserves safety-critical cells and revival is deterministic.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/cellular_resilience_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/chaos/apoptosis_test.exs`

**Exit Criteria**
Apoptosis and torpor are explicit lifecycle mechanisms with validated role-aware behavior.

## C04-S05 [todo] Chapter 4 / Section 5

**Source**
`docs/src/content/docs/part-2/chapter-4/5-chapter-wrap-up.md`

**Book Claim**
The regulated organism must remain coherent as DNA and epigenetic features evolve.

**Observed Code Reality**
No chapter-level regression suite exists for DNA plus lifecycle regulation.

**Gap**
Regulation features can drift independently.

**Implementation Tasks**
- Add Chapter 4 conformance tests for DNA, differentiation, apoptosis, and torpor.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
Chapter 4 regulation behavior is protected by dedicated regression coverage.

## Part III Milestone

Milestone condition:
All Chapter 5 and Chapter 6 phases are `[done]`, working memory and archive are clearly separated, and learning or consolidation behavior operates on real graph semantics with validated temporal consistency.

## C05-S01 [todo] Chapter 5 / Section 1

**Source**
`docs/src/content/docs/part-3/chapter-5/1-introduction.md`

**Book Claim**
The Rhizome is the topological memory substrate for the organism.

**Observed Code Reality**
Rhizome apps and NIFs exist, but the full memory-topology contract is not yet expressed as one coherent standard.

**Gap**
The repo lacks a shared topological memory contract governing working memory, archive, and temporal access patterns.

**Implementation Tasks**
- Define memory-topology contracts for active graph state, archive state, and consolidation flow.
- Add test helpers that assert those contracts in all memory-facing code.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test`

**Exit Criteria**
Memory topology expectations are explicit and used across the Rhizome boundary.

## C05-S02 [todo] Chapter 5 / Section 2

**Source**
`docs/src/content/docs/part-3/chapter-5/2-graph-vs-matrix.md`

**Book Claim**
The organism must reason and persist through graph topology, not through opaque matrix-like or blob interfaces.

**Observed Code Reality**
Memory code is graph-oriented, but several interfaces still pass opaque strings, ad hoc JSON blobs, or direct query strings.

**Gap**
Graph semantics are not enforced across all interfaces.

**Implementation Tasks**
- Replace opaque or stringly memory contracts with typed graph entities and operations.
- Minimize direct query-string construction in high-level Elixir modules.
- Add tests that reject unsupported opaque storage shortcuts.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/rhizome/memory_test.exs`

**Exit Criteria**
High-level memory interfaces expose graph semantics directly and forbid opaque shortcuts.

## C05-S03 [todo] Chapter 5 / Section 3

**Source**
`docs/src/content/docs/part-3/chapter-5/3-working-memory-vs-archive.md`

**Book Claim**
Working memory and archive must be separate tiers with distinct operational semantics.

**Observed Code Reality**
Memgraph and XTDB integrations both exist, but the boundary between active context and immutable archive is still porous in APIs and runtime usage.

**Gap**
Tier separation is incomplete and inconsistently enforced.

**Implementation Tasks**
- Define clear API boundaries for working-memory versus archive operations.
- Ensure execution outcomes, beliefs, and consolidation artifacts are persisted in the correct tier.
- Add tests that assert separation and correct projection between tiers.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/rhizome/service_integration_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/rhizome/bitemporal_test.exs`

**Exit Criteria**
Every memory path clearly targets working memory, archive, or projection between them.

## C05-S04 [todo] Chapter 5 / Section 4

**Source**
`docs/src/content/docs/part-3/chapter-5/4-multi-version-concurrency-control.md`

**Book Claim**
Temporal graph access must remain lock-free and bitemporal under concurrency.

**Observed Code Reality**
`Rhizome.Xtdb` supports a minimal submit and query shape, but the semantics are simplified and do not yet prove robust MVCC behavior.

**Gap**
Bitemporal guarantees, version retention, and concurrency semantics are underpowered.

**Implementation Tasks**
- Strengthen XTDB-facing submit and query semantics.
- Add version retention, bitemporal querying, and concurrent access tests.
- Ensure archive operations never degrade into destructive update assumptions.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/rhizome/temporal_query_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/property/memory_consistency_test.exs`

**Exit Criteria**
MVCC and bitemporal behavior are real, tested, and stable under concurrent access.

## C05-S05 [todo] Chapter 5 / Section 5

**Source**
`docs/src/content/docs/part-3/chapter-5/5-chapter-wrap-up.md`

**Book Claim**
Temporal graph behavior must remain stable as the system grows.

**Observed Code Reality**
There is no single chapter-level temporal graph parity suite.

**Gap**
Topology and temporal guarantees can regress independently.

**Implementation Tasks**
- Add Chapter 5 conformance tests covering graph semantics, tier separation, and MVCC.
- Require service-backed temporal validation in parity CI when the environment is available.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test`

**Exit Criteria**
Chapter 5 temporal graph parity is enforced by dedicated tests.

## C06-S01 [todo] Chapter 6 / Section 1

**Source**
`docs/src/content/docs/part-3/chapter-6/1-introduction.md`

**Book Claim**
Learning and consolidation must operate as an explicit synaptic plasticity loop.

**Observed Code Reality**
Relevant pieces exist across core, nervous system, and rhizome, but the full contract is not explicit.

**Gap**
The learning loop is fragmented and not defined end to end.

**Implementation Tasks**
- Define the end-to-end learning loop contract.
- Bind successful perception, action, failure, and sleep-cycle consolidation into one system model.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test`

**Exit Criteria**
The learning loop is documented, implemented, and validated as one flow.

## C06-S02 [todo] Chapter 6 / Section 2

**Source**
`docs/src/content/docs/part-3/chapter-6/2-hebbian-wiring-spatial-pooling.md`

**Book Claim**
The organism must convert repeated co-occurrence into structural graph organization through spatial pooling and Hebbian wiring.

**Observed Code Reality**
Sensory quantization exists, but no real spatial-pooling or co-occurrence wiring layer is implemented.

**Gap**
Learning from repeated structure is missing at the algorithmic level.

**Implementation Tasks**
- Add a structural co-occurrence and pooling pipeline for sensory and execution-derived inputs.
- Persist pooled abstractions into Rhizome with typed relations.
- Test that repeated patterns strengthen structural pathways.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/rhizome/optimizer_complex_test.exs`

**Exit Criteria**
Repeated structural patterns produce validated pooled graph organization.

## C06-S03 [todo] Chapter 6 / Section 3

**Source**
`docs/src/content/docs/part-3/chapter-6/3-the-pain-receptor.md`

**Book Claim**
Pain must be an immediate, typed, mathematically meaningful prediction-error signal that drives pruning.

**Observed Code Reality**
Pain signaling exists but uses mixed timestamp units, simplified metadata, and incomplete downstream graph linkage.

**Gap**
Pain is not yet a complete typed failure-to-graph update mechanism.

**Implementation Tasks**
- Standardize prediction-error schema, timestamps, and metadata semantics.
- Connect pain signals directly to typed graph update and pruning records.
- Add failure-mode tests for recursion resistance, delivery guarantees, and pruning behavior.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/nervous_system/test/nervous_system/pain_receptor_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/recovery_chaos_integration_test.exs`

**Exit Criteria**
Pain signals are typed, reliable, and directly linked to graph correction.

## C06-S04 [todo] Chapter 6 / Section 4

**Source**
`docs/src/content/docs/part-3/chapter-6/4-the-sleep-cycle-memory-consolidation.md`

**Book Claim**
Sleep must consolidate, abstract, prune, and archive memory rather than simply delete noisy structures.

**Observed Code Reality**
`Rhizome.ConsolidationManager` bridges to XTDB and optimizes the graph, but memory relief still performs coarse high-VFE deletion.

**Gap**
Consolidation is too destructive and not abstract enough.

**Implementation Tasks**
- Replace coarse deletion with abstraction, clustering, archival projection, and targeted pruning.
- Define which memories become super-nodes, which are archived, and which are pruned.
- Add replay and consolidation correctness tests.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/rhizome/sleep_consolidation_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test/rhizome/consolidation_manager_test.exs`

**Exit Criteria**
Sleep produces validated abstraction and archival behavior instead of blunt deletion.

## C06-S05 [todo] Chapter 6 / Section 5

**Source**
`docs/src/content/docs/part-3/chapter-6/5-chapter-wrap-up.md`

**Book Claim**
The adaptive map must remain coherent across live learning and offline consolidation.

**Observed Code Reality**
No chapter-level adaptive-map regression suite exists.

**Gap**
Learning and consolidation can drift apart.

**Implementation Tasks**
- Add Chapter 6 conformance tests covering Hebbian wiring, pain, and sleep-cycle consolidation.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/nervous_system/test`

**Exit Criteria**
Chapter 6 adaptive-map parity is defended by dedicated tests.

## Part IV Milestone

Milestone condition:
All Chapter 7 and Chapter 8 phases are `[done]`, sensory and motor boundaries are deterministic and secure, and all physical action crosses a validated planning-to-action membrane.

## C07-S01 [todo] Chapter 7 / Section 1

**Source**
`docs/src/content/docs/part-4/chapter-7/1-introduction.md`

**Book Claim**
Perception must be tightly bounded through explicit sensory organs with constrained ingest surfaces.

**Observed Code Reality**
Sensory support exists, but ingest surfaces and allowed modalities are not formalized.

**Gap**
The sensory perimeter is not explicitly defined or enforced.

**Implementation Tasks**
- Define allowed sensory organs and ingest surfaces.
- Reject unsupported ingestion paths by policy and tests.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test`

**Exit Criteria**
The sensory perimeter is explicit and enforced.

## C07-S02 [todo] Chapter 7 / Section 2

**Source**
`docs/src/content/docs/part-4/chapter-7/2-the-eyes-deterministic-parsing.md`

**Book Claim**
The Eyes must deterministically parse repositories into structural representations using Tree-sitter and project them into memory without hallucination.

**Observed Code Reality**
Tree-sitter and sensory NIF support exist, but `Sensory.StreamSupervisor` remains demo-like and does not implement a real deterministic repository parsing pipeline.

**Gap**
The Eyes are not yet a production deterministic parsing organ.

**Implementation Tasks**
- Build a repository parser pipeline using the sensory native layer and deterministic AST projection.
- Persist AST and repository topology into Rhizome.
- Add deterministic parsing and fidelity tests for repeated runs.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test/sensory/ast_accuracy_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test/sensory/perception_fidelity_test.exs`

**Exit Criteria**
Repository parsing is deterministic, structural, and graph-projected.

## C07-S03 [todo] Chapter 7 / Section 3

**Source**
`docs/src/content/docs/part-4/chapter-7/3-the-ears-telemetry-events.md`

**Book Claim**
The Ears must ingest telemetry, logs, and event streams through passive typed listeners.

**Observed Code Reality**
The repo has event flows and telemetry, but no dedicated passive telemetry-organ layer in sensory.

**Gap**
Telemetry and event ingestion are not modeled as a first-class sensory organ.

**Implementation Tasks**
- Add passive event ingestion cells for logs, webhooks, and runtime telemetry.
- Normalize events into typed sensory records before Rhizome projection.
- Add tests for event normalization and ingestion resilience.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/dashboard/test`

**Exit Criteria**
Telemetry and events are ingested through a dedicated typed sensory path.

## C07-S04 [todo] Chapter 7 / Section 4

**Source**
`docs/src/content/docs/part-4/chapter-7/4-the-skin-spatial-poolers.md`

**Book Claim**
The Skin must discover unknown binary or text protocols through generic spatial pooling.

**Observed Code Reality**
`Sensory.Quantizer` only performs simple byte quantization and dequantization.

**Gap**
The generic protocol-discovery layer does not exist.

**Implementation Tasks**
- Add a spatial-pooler subsystem for unknown protocol discovery.
- Bind its output to Hebbian wiring and Rhizome abstraction.
- Add tests for repeated-structure detection in opaque payloads.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test`

**Exit Criteria**
Unknown payload structures can be pooled and projected without ad hoc parsing shortcuts.

## C07-S05 [todo] Chapter 7 / Section 5

**Source**
`docs/src/content/docs/part-4/chapter-7/5-chapter-wrap-up.md`

**Book Claim**
The perimeter must remain deterministic, bounded, and non-blocking.

**Observed Code Reality**
No chapter-level sensory conformance suite exists.

**Gap**
Sensory drift can reintroduce heuristic or blocking behavior.

**Implementation Tasks**
- Add Chapter 7 conformance tests for deterministic parsing, passive telemetry ingestion, and non-blocking sensory operation.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test`

**Exit Criteria**
Chapter 7 sensory parity is continuously validated.

## C08-S01 [todo] Chapter 8 / Section 1

**Source**
`docs/src/content/docs/part-4/chapter-8/1-introduction.md`

**Book Claim**
The transition from planning to action must cross a strict validation membrane.

**Observed Code Reality**
Planning and execution are linked loosely; no unified planning-to-action contract exists.

**Gap**
There is no single authoritative boundary object for planned action.

**Implementation Tasks**
- Define typed execution intent schemas for all motor actions.
- Require all motor execution to originate from those schemas and pass validation.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sandbox/test`

**Exit Criteria**
Every action is derived from and validated against a typed execution-intent contract.

## C08-S02 [todo] Chapter 8 / Section 2

**Source**
`docs/src/content/docs/part-4/chapter-8/2-linguistic-motor-cells.md`

**Book Claim**
Operator-facing output should be generated through a constrained non-LLM linguistic motor surface.

**Observed Code Reality**
The repo has no GF-equivalent or constrained linguistic motor layer.

**Gap**
Human-facing output is not modeled as a dedicated motor organ.

**Implementation Tasks**
- Add a clinical, constrained operator-output layer for graph-to-language translation.
- Ensure the output layer reads typed graph or plan state rather than free-form generation.
- Add tests for deterministic phrasing and safety constraints.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/dashboard/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
Human-facing output is produced by a bounded linguistic motor surface derived from internal state.

## C08-S03 [todo] Chapter 8 / Section 3

**Source**
`docs/src/content/docs/part-4/chapter-8/3-the-sandbox.md`

**Book Claim**
The sandbox must enforce WRS-gated irreversible action through isolated microVM execution and telemetry ingestion.

**Observed Code Reality**
Firecracker provisioning and telemetry capture exist, but WRS gating, plan-driven patch application, and mounted workspace mutation loops are incomplete.

**Gap**
The sandbox is a partial membrane rather than the full planning Rubicon the book describes.

**Implementation Tasks**
- Implement WRS pre-commit authorization for execution intents.
- Add plan-driven workspace mutation, compile, test, and telemetry loops inside the sandbox.
- Ensure host mutation is impossible outside sandbox execution.
- Expand audit and provenance capture for action decisions.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sandbox/test`
- Firecracker-backed end-to-end action validation in a real host environment.

**Exit Criteria**
Irreversible action is gated, isolated, auditable, and telemetry-fed end to end.

## C08-S04 [todo] Chapter 8 / Section 4

**Source**
`docs/src/content/docs/part-4/chapter-8/4-friction-mirror-neurons.md`

**Book Claim**
Human feedback and friction must prune socio-linguistic pathways without corrupting core architectural rigor.

**Observed Code Reality**
There is no dedicated feedback, friction, or mirror-neuron subsystem.

**Gap**
The alignment loop for human interaction is missing entirely.

**Implementation Tasks**
- Capture conversational friction and operator correction events as typed graph records.
- Separate style adaptation from core architectural decisions.
- Add pruning and reinforcement logic for operator-facing phrasing only.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/dashboard/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
Human feedback affects bounded socio-linguistic pathways without contaminating core logic.

## C08-S05 [todo] Chapter 8 / Section 5

**Source**
`docs/src/content/docs/part-4/chapter-8/5-chapter-wrap-up.md`

**Book Claim**
Action and feedback loops must remain safe and coherent.

**Observed Code Reality**
No chapter-level action conformance suite exists.

**Gap**
Planning, membrane, and operator feedback can drift independently.

**Implementation Tasks**
- Add Chapter 8 conformance tests covering execution intents, sandbox action, linguistic output, and friction handling.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sandbox/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/dashboard/test`

**Exit Criteria**
Chapter 8 action parity is protected by dedicated validation.

## Part V Milestone

Milestone condition:
All Chapter 9 and Chapter 10 phases are `[done]`, metabolism is a real policy input, and sovereign directives plus cross-workspace behavior are implemented and validated.

## C09-S01 [todo] Chapter 9 / Section 1

**Source**
`docs/src/content/docs/part-5/chapter-9/1-introduction.md`

**Book Claim**
Needs and metabolism must act as real internal drives for runtime behavior.

**Observed Code Reality**
Metabolism exists, but mainly as telemetry and coarse pressure reactions.

**Gap**
Needs are not yet a first-class runtime policy layer, and the system does not yet have a formal model for how needs and values become objective weights.

**Implementation Tasks**
- Define a metabolism policy model shared by planning, execution, and lifecycle systems.
- Define a need and value model that maps metabolic pressure, sovereign objectives, and operator priorities into weighted priors.
- Ensure scheduling and goal emergence can consume metabolic state.
- Require the planning layer and surprise calculation layer to consume those weighted priors.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/metabolic_daemon_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
Metabolism is an authoritative runtime policy input, not just a monitor, and needs or values are represented as explicit weighted priors.

## C09-S02 [todo] Chapter 9 / Section 2

**Source**
`docs/src/content/docs/part-5/chapter-9/2-the-atp-analogue.md`

**Book Claim**
ATP-like scarcity must shape scheduling, admission, pruning, and homeostasis.

**Observed Code Reality**
Pressure drives telemetry, apoptosis, and torpor, but not yet a broad admission-control and scheduling system.

**Gap**
Metabolic pressure is too reactive and not sufficiently integrated into all action paths, and ATP policy is not yet merged with need and value weighting for improvement prioritization.

**Implementation Tasks**
- Add admission control for cell spawning, sandbox execution, and planning based on ATP budget.
- Expose ATP state as a policy input to nervous system, sandbox, and core planning.
- Merge ATP policy with weighted need and value priors so improvement work is prioritized by both scarcity and objective importance.
- Add deterministic thresholds and tests for scheduling decisions.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/metabolic_tier4_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/service_health_test.exs`

**Exit Criteria**
ATP pressure changes real scheduling and admission decisions across the organism, and those decisions are modulated by weighted needs and values.

## C09-S03 [todo] Chapter 9 / Section 3

**Source**
`docs/src/content/docs/part-5/chapter-9/3-epistemic-foraging-curiosity.md`

**Book Claim**
Idle compute must probe low-confidence graph edges through bounded sandboxed exploration.

**Observed Code Reality**
No explicit epistemic-foraging subsystem exists.

**Gap**
Curiosity-driven low-confidence probing is missing.

**Implementation Tasks**
- Add low-confidence edge selection and idle-time exploration logic.
- Route all exploratory execution through the sandbox membrane.
- Persist exploratory outcomes as confidence updates in Rhizome.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sandbox/test`

**Exit Criteria**
Low-confidence edges can be safely and deterministically probed during idle periods.

## C09-S04 [todo] Chapter 9 / Section 4

**Source**
`docs/src/content/docs/part-5/chapter-9/4-the-simulation-daemon-dreams.md`

**Book Claim**
The organism must dream by exploring hypothetical architectural permutations in isolated sandboxes using historical telemetry.

**Observed Code Reality**
No dedicated simulation-daemon subsystem exists.

**Gap**
Macro-architectural dreaming and permutation search are absent.

**Implementation Tasks**
- Build a simulation daemon process tree for hypothetical architecture permutations.
- Feed it historical telemetry and Rhizome traces.
- Execute permutations through isolated sandboxes and project results back into Rhizome.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- Firecracker-backed dream-state validation in a real host environment.

**Exit Criteria**
Idle dream-state permutation and consolidation behavior exists and is validated.

## C09-S05 [todo] Chapter 9 / Section 5

**Source**
`docs/src/content/docs/part-5/chapter-9/5-chapter-wrap-up.md`

**Book Claim**
Drive and homeostasis must remain coherent across ATP, curiosity, and dreaming.

**Observed Code Reality**
No chapter-level drive conformance suite exists.

**Gap**
Metabolic policy features can drift apart.

**Implementation Tasks**
- Add Chapter 9 conformance tests for ATP policy, curiosity, and simulation-daemon behavior.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
Chapter 9 drive behavior is defended by dedicated validation.

## C10-S01 [todo] Chapter 10 / Section 1

**Source**
`docs/src/content/docs/part-5/chapter-10/1-introduction.md`

**Book Claim**
The organism must operate under sovereign architecture and symbiotic law rather than ephemeral prompt control.

**Observed Code Reality**
No sovereignty control-plane implementation exists beyond local runtime config and DNA.

**Gap**
Persistent sovereign law and symbiotic governance are absent, and there is no formal representation of values that can influence attractor weighting and improvement choices.

**Implementation Tasks**
- Define sovereignty control-plane boundaries across objectives, attractors, plans, and refusal.
- Define objective schemas that distinguish hard mandates, soft values, and evolving needs, each with explicit weights and precedence.
- Add integration points from sovereign state into planning and metabolism.
- Require sovereign values to flow into both attractor selection and variational free energy weighting.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
Sovereignty becomes an explicit runtime control plane with weighted mandates, values, and needs.

## C10-S02 [todo] Chapter 10 / Section 2

**Source**
`docs/src/content/docs/part-5/chapter-10/2-sovereign-directives.md`

**Book Claim**
High-level goals must be loaded from persistent objective manifests and projected into localized `.nexical/plan.yml` execution blueprints.

**Observed Code Reality**
Neither `~/.karyon/objectives/` nor `.nexical/plan.yml` exists in the repo implementation.

**Gap**
Persistent objectives, attractor projection, and localized execution blueprints are missing, and there is no mechanism for turning declared needs or values into weighted attractor priors.

**Implementation Tasks**
- Implement objective manifest ingestion from `~/.karyon/objectives/`.
- Project mandates into Rhizome attractor states.
- Define objective manifest fields for hard constraints, soft values, evolving needs, and their weights or precedence.
- Generate localized `.nexical/plan.yml` working-memory plans per workspace.
- Ensure planning cells consume attractors instead of ephemeral textual control inputs.
- Ensure modified objective weights measurably change attractor ranking, plan generation, and improvement prioritization.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- Manual verification of objective ingestion and plan generation in a local workspace.
- Manual or automated verification that changing objective weights changes selected attractors and emitted plans.

**Exit Criteria**
Persistent objectives and localized execution blueprints exist, weighted priors are represented in Rhizome attractors, and changing objective weights changes planning behavior.

## C10-S03 [todo] Chapter 10 / Section 3

**Source**
`docs/src/content/docs/part-5/chapter-10/3-defiance-and-homeostasis.md`

**Book Claim**
The organism must detect paradoxes, refuse destructive directives, and negotiate when commands violate sovereign law or homeostasis.

**Observed Code Reality**
There is no explicit paradox-detection, refusal, or negotiation subsystem.

**Gap**
The sovereignty safety loop is missing, and refusal policy cannot yet account for the relative weight of hard mandates, soft values, evolving needs, and metabolic risk.

**Implementation Tasks**
- Add paradox detection between mandates, plans, and metabolic limits.
- Implement refusal thresholds and operator-visible negotiation output.
- Define how weighted values and needs influence refusal versus compromise when hard mandates are not violated.
- Persist paradox and refusal events into Rhizome.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/dashboard/test`

**Exit Criteria**
The system can refuse or renegotiate conflicting directives through explicit policy grounded in mandate precedence, weighted values, weighted needs, and metabolic risk.

## C10-S04 [todo] Chapter 10 / Section 4

**Source**
`docs/src/content/docs/part-5/chapter-10/4-the-cross-workspace-architect.md`

**Book Claim**
The organism must coordinate persistent intelligence across multiple workspaces with localized execution limbs and shared memory.

**Observed Code Reality**
No cross-workspace architecture exists beyond a single repo-local implementation.

**Gap**
Multi-workspace planning and localized execution contracts are absent.

**Implementation Tasks**
- Define central versus local workspace boundaries.
- Add shared-memory support for multiple repositories and localized `.nexical/plan.yml` outputs.
- Implement cross-workspace planning and execution coordination.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- Manual multi-workspace integration verification.

**Exit Criteria**
Cross-workspace planning and localized limb execution are implemented and validated.

## C10-S05 [todo] Chapter 10 / Section 5

**Source**
`docs/src/content/docs/part-5/chapter-10/5-chapter-wrap-up.md`

**Book Claim**
The sovereign organism must remain coherent across objectives, refusal, and multi-workspace action.

**Observed Code Reality**
No chapter-level sovereignty conformance suite exists.

**Gap**
Objectives, defiance, and cross-workspace behavior can drift apart.

**Implementation Tasks**
- Add Chapter 10 conformance tests covering objectives, blueprint generation, paradox handling, and cross-workspace planning.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`

**Exit Criteria**
Chapter 10 sovereignty parity is guarded by dedicated validation.

## Part VI Milestone

Milestone condition:
All Chapter 11 and Chapter 12 phases are `[done]`, the organism has a validated bootstrapping and observability model, and curriculum plus memory distribution features operate as a closed lifecycle.

## C11-S01 [todo] Chapter 11 / Section 1

**Source**
`docs/src/content/docs/part-6/chapter-11/1-introduction.md`

**Book Claim**
Theory must compile into a concrete bootstrapping and lifecycle system.

**Observed Code Reality**
Many components exist, but there is no unified operational maturity model tied to the book.

**Gap**
Bootstrapping targets are not expressed as a single implementation program.

**Implementation Tasks**
- Define the operational maturity model covering build, deploy, observe, and distribute.
- Tie that model to later chapter validation.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix compile`

**Exit Criteria**
Bootstrapping and maturity targets are explicit and actionable.

## C11-S02 [todo] Chapter 11 / Section 2

**Source**
`docs/src/content/docs/part-6/chapter-11/2-the-monorepo-pipeline.md`

**Book Claim**
The monorepo pipeline must preserve separation between the engine and target execution workspaces.

**Observed Code Reality**
The umbrella app and release flow exist, but engine-versus-target-workspace separation is not implemented as the book describes.

**Gap**
The repo behaves as the active workspace rather than clearly separating organism core from execution limbs.

**Implementation Tasks**
- Align bootstrap, release, and execution flow with the engine-versus-target-workspace model.
- Ensure sandbox mutation always occurs in target workspaces rather than the core engine tree.
- Add build and release checks that reflect the monorepo pipeline model.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix compile`
- Release bootstrap and smoke validation.

**Exit Criteria**
The engine and target workspace model is explicit and enforced operationally.

## C11-S03 [todo] Chapter 11 / Section 3

**Source**
`docs/src/content/docs/part-6/chapter-11/3-visualizing-the-rhizome.md`

**Book Claim**
Operators need real-time observability over the Rhizome and organism state, not only local health metrics.

**Observed Code Reality**
Dashboard health and telemetry bridges exist, but topology, temporal state, and graph visualization are absent.

**Gap**
Observability is much thinner than the book requires.

**Implementation Tasks**
- Expand dashboard data sources beyond metabolic snapshots.
- Surface graph health, temporal memory state, active cells, and organism topology.
- Add operator views for prediction errors, consolidation, and sovereign state.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/dashboard/test`

**Exit Criteria**
Dashboard observability reflects real Rhizome and organism state.

## C11-S04 [todo] Chapter 11 / Section 4

**Source**
`docs/src/content/docs/part-6/chapter-11/4-the-distributed-experience-engram.md`

**Book Claim**
The organism must package and distribute portable, secure memory subsets as engrams.

**Observed Code Reality**
`Core.Engram` already supports portable capture and inject flows, but distribution semantics and real subset selection are still limited.

**Gap**
Engrams exist, but not yet as fully queryable, distributable memory products tied to real workflows.

**Implementation Tasks**
- Add selective subset extraction and import semantics.
- Tie engram generation to real use cases, provenance, and compatibility guarantees.
- Add validation for portable exchange and partial memory hydration.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/engram_test.exs`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/tier5_global_test.exs`

**Exit Criteria**
Engrams are portable, selective, and safe for real distribution workflows.

## C11-S05 [todo] Chapter 11 / Section 5

**Source**
`docs/src/content/docs/part-6/chapter-11/5-chapter-wrap-up.md`

**Book Claim**
Genesis architecture must remain coherent across pipeline, observability, and distributed memory.

**Observed Code Reality**
No chapter-level operational genesis conformance suite exists.

**Gap**
Release, observability, and engram behavior can drift apart.

**Implementation Tasks**
- Add Chapter 11 conformance tests for pipeline, observability, and engram flows.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test`

**Exit Criteria**
Chapter 11 parity is enforced by operational conformance validation.

## C12-S01 [todo] Chapter 12 / Section 1

**Source**
`docs/src/content/docs/part-6/chapter-12/1-introduction.md`

**Book Claim**
The organism requires a real maturation lifecycle rather than ad hoc operation.

**Observed Code Reality**
There is no unified curriculum subsystem.

**Gap**
Training and maturation are missing as a first-class operational capability.

**Implementation Tasks**
- Define the curriculum and maturation lifecycle model.
- Tie the model to baseline ingestion, telemetry, teaching, and intent drift.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix compile`

**Exit Criteria**
The maturation lifecycle is explicit and implementable.

## C12-S02 [todo] Chapter 12 / Section 2

**Source**
`docs/src/content/docs/part-6/chapter-12/2-the-baseline-diet.md`

**Book Claim**
The organism must ingest a curated deterministic AST baseline before higher-order action loops dominate.

**Observed Code Reality**
The repo contains baseline task scaffolding, but no complete baseline-diet ingestion workflow tied to AST curriculum guarantees.

**Gap**
The baseline diet is incomplete as a curriculum feature.

**Implementation Tasks**
- Build curated AST baseline ingestion into the sensory and Rhizome flow.
- Define acceptance criteria for baseline completeness and quality.
- Add tests proving the baseline establishes structural grammar before later action loops.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test`

**Exit Criteria**
Baseline-diet ingestion exists and establishes the required deterministic structural substrate.

## C12-S03 [todo] Chapter 12 / Section 3

**Source**
`docs/src/content/docs/part-6/chapter-12/3-execution-telemetry.md`

**Book Claim**
Compiler, test, and runtime execution telemetry must be formalized as training input and prediction-error evidence.

**Observed Code Reality**
Execution outcomes are persisted, but telemetry storage, tagging, replay, and training reuse are incomplete.

**Gap**
Execution telemetry exists only partially as a curriculum artifact.

**Implementation Tasks**
- Standardize execution telemetry schema, tags, provenance, and replay hooks.
- Project telemetry into Rhizome and XTDB as curriculum-ready artifacts.
- Add replay tests for telemetry-driven learning flows.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test`

**Exit Criteria**
Execution telemetry is stored, replayable, and reusable as training input.

## C12-S04 [todo] Chapter 12 / Section 4

**Source**
`docs/src/content/docs/part-6/chapter-12/4-the-synthetic-oracle-curriculum-the-teacher-daemon.md`

**Book Claim**
The organism must generate active exams from docs and specs through a teacher-daemon curriculum.

**Observed Code Reality**
No teacher-daemon subsystem exists.

**Gap**
Synthetic curriculum generation from documentation is absent.

**Implementation Tasks**
- Build a teacher daemon that converts docs and specs into active exercises.
- Feed generated exercises through sandbox execution and telemetry.
- Persist outcomes and performance traces into Rhizome.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- Manual or automated curriculum-run verification against docs sources.

**Exit Criteria**
Synthetic curriculum generation and evaluation exist and are persisted as organism learning data.

## C12-S05 [todo] Chapter 12 / Section 5

**Source**
`docs/src/content/docs/part-6/chapter-12/5-abstract-intent.md`

**Book Claim**
The organism must learn architectural intent and drift by ingesting ADRs, history, and documentation deltas.

**Observed Code Reality**
No ADR or git-history ingestion pipeline exists.

**Gap**
Abstract intent and documentation drift are not represented in Rhizome.

**Implementation Tasks**
- Add ADR and git-history ingestion into Rhizome.
- Represent intent drift and implementation drift as graph entities.
- Add tests that compare declared intent to observed implementation state.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test`
- `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test`

**Exit Criteria**
Architectural intent and drift are represented and testable in memory.

## C12-S06 [todo] Chapter 12 / Section 6

**Source**
`docs/src/content/docs/part-6/chapter-12/6-chapter-wrap-up.md`

**Book Claim**
The architect must emerge through a closed-loop lifecycle from baseline through telemetry, synthetic curriculum, and abstract intent.

**Observed Code Reality**
No chapter-level closed-loop maturation suite exists.

**Gap**
Lifecycle features can remain fragmented and unproven as a system.

**Implementation Tasks**
- Add Chapter 12 conformance tests for baseline diet, execution telemetry, teacher daemon, and abstract-intent ingestion.
- Require end-to-end lifecycle validation before whole-book parity can be declared.

**Validation**
- `cd /home/adrian/Projects/nexical/karyon/app && mix test`

**Exit Criteria**
Chapter 12 validates a full closed maturation loop from baseline to drift correction.

## Final Milestones

- `[todo]` Part I Complete: Chapters 1 and 2 are implemented and validated.
- `[todo]` Part II Complete: Chapters 3 and 4 are implemented and validated.
- `[todo]` Part III Complete: Chapters 5 and 6 are implemented and validated.
- `[todo]` Part IV Complete: Chapters 7 and 8 are implemented and validated.
- `[todo]` Part V Complete: Chapters 9 and 10 are implemented and validated.
- `[todo]` Part VI Complete: Chapters 11 and 12 are implemented and validated.
- `[todo]` Whole-Book Architectural Parity Complete: Every `Cxx-Syy` phase is `[done]`, all conflict-ledger items are either resolved or explicitly accepted, and the implementation matches the canonical book guidance with validated runtime behavior.
