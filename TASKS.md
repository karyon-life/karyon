# Karyon Architectural Parity Task Tracker

This file mirrors [`PLAN.md`](/home/adrian/Projects/nexical/karyon/PLAN.md) and tracks implementation progress for each chapter-section phase in the canonical book source at `docs/src/content/docs/**`.

## Canonical Sources

- `docs/src/content/docs/**`
- [`AGENTS.md`](/home/adrian/Projects/nexical/karyon/AGENTS.md)
- [`SPEC.md`](/home/adrian/Projects/nexical/karyon/SPEC.md)

## Conflict Ledger

- [ ] Storage bridge contract resolved to `virtio-blk` plus overlay-backed writable workspaces and reflected in membrane work.
Completion criterion: `PLAN.md` documents the resolved `virtio-blk` plus overlay contract, and sandbox implementation work follows that contract instead of `virtio-fs`.

## Part I: The Biological Edge In Systems

- [x] `C01-S01` Introduction
Completion criterion: an active-inference parity rubric exists and tests fail on monolithic or stateless regressions.

- [x] `C01-S02` The Statistical Dead End
Completion criterion: core planning uses typed graph-backed state transitions instead of prompt-response shortcuts.

- [x] `C01-S03` Catastrophic Forgetting & Hardware Economics
Completion criterion: durable recovery and hardware-budget enforcement are validated across the main loop.

- [x] `C01-S04` The Predictive Coding Failure
Completion criterion: prediction error is the sole authoritative trigger for structural adaptation, and surprise is computed through a typed variational free energy model rather than a hardcoded placeholder.

- [x] `C01-S05` Chapter Wrap-Up
Completion criterion: Chapter 1 conformance tests exist and fail on regression.

- [x] `C02-S01` Introduction
Completion criterion: biology-first architecture invariants are executable across the umbrella.

- [x] `C02-S02` The Cellular State Machine
Completion criterion: actor isolation and decentralized discovery are validated under load.

- [x] `C02-S03` Predictive Processing
Completion criterion: expectation formation, weighted surprise, and structural response form one reliable loop.

- [x] `C02-S04` Abstract State Prediction
Completion criterion: predictions and plans are represented as typed abstract states, and attractors carry weighted needs, values, and objective priors.

- [x] `C02-S05` Continuous Local Plasticity
Completion criterion: real local pathways support validated strengthen and prune behavior.

- [x] `C02-S06` Chapter Wrap-Up
Completion criterion: Chapter 2 biology-first behavior is enforced by dedicated tests.

- [x] Part I Complete
Completion criterion: every `C01-*` and `C02-*` item is complete and validated.

## Part II: Anatomy Of The Organism

- [x] `C03-S01` Introduction
Completion criterion: subsystem boundaries are explicit, documented, and test-backed.

- [x] `C03-S02` The Microkernel Philosophy
Completion criterion: core remains sterile and free of embedded project semantics.

- [x] `C03-S03` Erlang/BEAM (Cytoplasm)
Completion criterion: BEAM-scale concurrency and crash-only recovery are validated.

- [x] `C03-S04` Rust NIFs (Organelles)
Completion criterion: all NIF boundaries are typed, safe, and stress-tested.

- [x] `C03-S05` The KVM/QEMU Membrane
Completion criterion: all mutation and compile actions cross a validated `virtio-blk` plus overlay membrane contract.

- [x] `C03-S06` The Nervous System
Completion criterion: ZeroMQ and NATS role separation plus backpressure behavior are validated.

- [x] `C03-S07` Chapter Wrap-Up
Completion criterion: Chapter 3 cross-app contract tests exist and pass.

- [x] `C04-S01` Introduction
Completion criterion: DNA and epigenetic control-plane boundaries are explicit and test-backed.

- [x] `C04-S02` Declarative Genetics
Completion criterion: DNA schema, inheritance, and allowed-action policy are authoritative and validated.

- [x] `C04-S03` The Epigenetic Supervisor
Completion criterion: cells are differentiated through environmental transcription rather than uniform spawning.

- [x] `C04-S04` Apoptosis & Digital Torpor
Completion criterion: lifecycle states and role-aware apoptosis or torpor behavior are formalized and tested.

- [x] `C04-S05` Chapter Wrap-Up
Completion criterion: Chapter 4 regulation behavior is defended by dedicated regression tests.

- [x] Part II Complete
Completion criterion: every `C03-*` and `C04-*` item is complete and validated.

## Part III: The Rhizome

- [ ] `C05-S01` Introduction
Completion criterion: memory-topology contracts are explicit across the Rhizome boundary.

- [ ] `C05-S02` Graph vs Matrix
Completion criterion: high-level memory interfaces expose graph semantics and reject opaque shortcuts.

- [ ] `C05-S03` Working Memory vs Archive
Completion criterion: working-memory and archive operations are clearly separated and tested.

- [ ] `C05-S04` Multi-Version Concurrency Control
Completion criterion: bitemporal and MVCC behavior is validated under concurrent access.

- [ ] `C05-S05` Chapter Wrap-Up
Completion criterion: Chapter 5 temporal graph parity is enforced by dedicated tests.

- [ ] `C06-S01` Introduction
Completion criterion: the end-to-end learning and consolidation loop is explicit and validated.

- [ ] `C06-S02` Hebbian Wiring & Spatial Pooling
Completion criterion: repeated structures produce validated pooled graph organization.

- [ ] `C06-S03` The Pain Receptor
Completion criterion: pain signals are typed, reliable, and directly linked to graph correction.

- [ ] `C06-S04` The Sleep Cycle
Completion criterion: sleep performs abstraction, archival projection, and targeted pruning instead of blunt deletion.

- [ ] `C06-S05` Chapter Wrap-Up
Completion criterion: Chapter 6 adaptive-map parity is defended by dedicated tests.

- [ ] Part III Complete
Completion criterion: every `C05-*` and `C06-*` item is complete and validated.

## Part IV: Perception And Action

- [ ] `C07-S01` Introduction
Completion criterion: the sensory perimeter is explicit and enforced.

- [ ] `C07-S02` The Eyes
Completion criterion: repository parsing is deterministic, structural, and graph-projected.

- [ ] `C07-S03` The Ears
Completion criterion: telemetry and events are ingested through a dedicated typed sensory path.

- [ ] `C07-S04` The Skin
Completion criterion: unknown payload structures can be pooled and projected without ad hoc parsing shortcuts.

- [ ] `C07-S05` Chapter Wrap-Up
Completion criterion: Chapter 7 sensory parity is continuously validated.

- [ ] `C08-S01` Introduction
Completion criterion: every action originates from a typed execution-intent contract.

- [ ] `C08-S02` Linguistic Motor Cells
Completion criterion: human-facing output is generated by a bounded operator-output layer.

- [ ] `C08-S03` The Sandbox
Completion criterion: irreversible action is gated, isolated, auditable, and telemetry-fed end to end.

- [ ] `C08-S04` Friction & Mirror Neurons
Completion criterion: human feedback prunes bounded socio-linguistic pathways without contaminating core logic.

- [ ] `C08-S05` Chapter Wrap-Up
Completion criterion: Chapter 8 action parity is protected by dedicated validation.

- [ ] Part IV Complete
Completion criterion: every `C07-*` and `C08-*` item is complete and validated.

## Part V: Consciousness And Autonomy

- [ ] `C09-S01` Introduction
Completion criterion: metabolism is an authoritative runtime policy input, and needs or values are represented as explicit weighted priors.

- [ ] `C09-S02` The ATP Analogue
Completion criterion: ATP pressure changes scheduling and admission decisions across the organism, and those decisions are modulated by weighted needs and values.

- [ ] `C09-S03` Epistemic Foraging
Completion criterion: low-confidence edges can be safely probed during idle periods.

- [ ] `C09-S04` The Simulation Daemon
Completion criterion: dream-state permutation and consolidation behavior exists and is validated.

- [ ] `C09-S05` Chapter Wrap-Up
Completion criterion: Chapter 9 drive behavior is defended by dedicated validation.

- [ ] `C10-S01` Introduction
Completion criterion: sovereignty is implemented as an explicit runtime control plane with weighted mandates, values, and needs.

- [ ] `C10-S02` Sovereign Directives
Completion criterion: persistent objectives and localized `.nexical/plan.yml` blueprints drive planning, and changing objective weights changes attractor ranking and plan output.

- [ ] `C10-S03` Defiance and Homeostasis
Completion criterion: paradox detection, refusal, and negotiation behavior are explicit and validated against mandate precedence, weighted values, weighted needs, and metabolic risk.

- [ ] `C10-S04` The Cross-Workspace Architect
Completion criterion: cross-workspace planning and localized limb execution are implemented and verified.

- [ ] `C10-S05` Chapter Wrap-Up
Completion criterion: Chapter 10 sovereignty parity is guarded by dedicated validation.

- [ ] Part V Complete
Completion criterion: every `C09-*` and `C10-*` item is complete and validated.

## Part VI: Maturation & Lifecycle Execution

- [ ] `C11-S01` Introduction
Completion criterion: bootstrapping and operational maturity targets are explicit and actionable.

- [ ] `C11-S02` The Monorepo Pipeline
Completion criterion: engine and target workspace roles are enforced operationally.

- [ ] `C11-S03` Visualizing the Rhizome
Completion criterion: dashboard observability reflects real Rhizome and organism state.

- [ ] `C11-S04` The Distributed Experience Engram
Completion criterion: engrams are portable, selective, and safe for real distribution workflows.

- [ ] `C11-S05` Chapter Wrap-Up
Completion criterion: Chapter 11 parity is enforced by operational conformance validation.

- [ ] `C12-S01` Introduction
Completion criterion: the maturation lifecycle is explicit and implementable.

- [ ] `C12-S02` The Baseline Diet
Completion criterion: baseline-diet ingestion establishes the required deterministic structural substrate.

- [ ] `C12-S03` Execution Telemetry
Completion criterion: execution telemetry is stored, replayable, and reusable as training input.

- [ ] `C12-S04` The Synthetic Oracle Curriculum
Completion criterion: synthetic curriculum generation and evaluation exist and persist learning data.

- [ ] `C12-S05` Abstract Intent
Completion criterion: architectural intent and implementation drift are represented and testable in memory.

- [ ] `C12-S06` Chapter Wrap-Up
Completion criterion: a full closed maturation loop from baseline to drift correction is validated.

- [ ] Part VI Complete
Completion criterion: every `C11-*` and `C12-*` item is complete and validated.

## Final Milestone

- [ ] Complete Architectural Parity
Completion criterion: every `Cxx-Syy` item is complete, all required validations pass, and whole-book parity is achieved with any remaining conflict-ledger items explicitly resolved or accepted.
