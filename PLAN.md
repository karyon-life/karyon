# Karyon Autonomous Production Readiness Plan

This file is the execution source of truth for bringing Karyon from its current scaffolded state to a production-ready platform. It is designed for long autonomous runs. It must be detailed enough that an agent can select work, implement it, validate it, update status, and continue without inventing architecture or drifting from the organism model.

This plan must remain aligned with:

- [`AGENTS.md`](/home/adrian/Projects/nexical/karyon/AGENTS.md)
- [`SPEC.md`](/home/adrian/Projects/nexical/karyon/SPEC.md)
- the implementation reality of the `app/` umbrella and docs tree

## Program Objectives

All work under this plan must move the system toward these outcomes:

1. A truthful organism whose runtime behavior matches its claims.
2. Stable inter-app contracts across Elixir, Rust NIFs, and external services.
3. Secure embodied execution through a real sandbox membrane.
4. Deterministic sensory and memory flows with explicit feedback loops.
5. Observable, testable, deployable production operations.
6. Standardized development that preserves topological sterility and biomimetic constraints.

## Operating Rules

1. Do not start a task whose dependencies are not complete.
2. Do not treat simulated behavior as production behavior.
3. Prefer correctness and contract repair before scale or optimization.
4. Keep app boundaries typed and explicit.
5. For every completed task, run the listed validation commands or document why they could not run.
6. If a task touches a cross-app contract, update both sides in the same work unit.
7. If an external dependency is required and unavailable, mark the task blocked and proceed to the next unblocked task.
8. Do not introduce central registries, shared mutable state, or synchronous control bottlenecks that violate the organism model.
9. Do not hardcode project semantics into the sterile core if the behavior belongs in DNA, Rhizome state, or declarative configuration.
10. When a task changes runtime behavior, update tests and docs in the same work unit unless explicitly blocked.
11. Do not advance a phase on partial implementation. Advance only on validated system state.
12. Prefer bounded, cohesive changes over broad speculative refactors.

## Architectural Guardrails

These constraints apply to every task in this plan:

- Prefer OTP process isolation and asynchronous message passing over shared state.
- Keep `core` sterile. Behavioral specialization belongs in YAML DNA, Rhizome state, or bounded edge modules.
- Keep NIF boundaries explicit, typed, and failure-safe. Rust code must not rely on panic paths crossing into Elixir.
- Any operation that can block the BEAM must be treated as a dirty or externalized operation.
- Sandbox changes must preserve air-gap, bounded-resource, and host-protection assumptions.
- Sensory parsing must remain deterministic. Do not reintroduce heuristic parsing into core reasoning paths.
- Dashboard and docs must report actual state, not aspirational or mocked behavior, unless explicitly labeled as simulated.
- System behavior must fail closed on unsafe or unsupported conditions.

## Status Model

Use these markers when updating this plan:

- `[todo]` not started
- `[doing]` actively in progress
- `[blocked]` cannot proceed because of an external dependency or upstream task
- `[done]` completed and validated

### Status update requirements

Whenever a task status changes, record:

- date
- owner or agent identifier if available
- short summary of what changed
- validation run
- blocker reason if status becomes `[blocked]`

If this plan is being updated manually, append updates directly under the task in a `Progress notes:` subsection.

## Standard Task Workflow

Every implementation task should follow this sequence:

1. Confirm prerequisites and dependencies.
2. Read the relevant files and identify contract boundaries.
3. Decide whether the change is local or cross-app.
4. Implement the smallest cohesive slice that leaves the system in a valid state.
5. Add or update tests covering intended behavior.
6. Run the minimum required validation commands.
7. Update docs if behavior, operations, or architecture assumptions changed.
8. Update task status and progress notes in this plan.

## Standard Definition Of Done

A task is only `[done]` when all applicable items below are true:

- the code compiles
- the touched behavior is validated by existing or new tests
- callers and callees agree on any changed contract
- no fake success path was introduced
- logs and error handling are explicit enough for debugging
- related docs or inline comments are updated if behavior changed materially
- the plan entry reflects the current status accurately

## Minimum Validation Matrix

Unless a task explicitly states a narrower or broader scope, use this matrix:

- Elixir-only local logic change:
  - `mix compile`
  - targeted app tests
- Cross-app Elixir contract change:
  - `mix compile`
  - targeted tests for both apps
- NIF contract or Rust behavior change:
  - `mix compile`
  - targeted Elixir app tests
  - relevant native tests if available
- Sandbox or service integration change:
  - targeted app tests
  - integration validation if the environment is available
- Docs-only change:
  - path/build/manual verification appropriate to the docs surface

## Cross-App Change Rules

If a task touches one of these boundaries, the task is not complete until both sides are updated:

- `core` <-> `rhizome`
- `core` <-> `sandbox`
- `core` <-> `nervous_system`
- `sensory` <-> `rhizome`
- `dashboard` <-> telemetry emitters
- docs <-> actual runtime behavior

For each cross-app change:

- define the contract shape first
- update producer and consumer in the same task or tightly linked subtask pair
- add validation on both sides
- remove or rewrite tests that encoded the old contract

## File Ownership Guidance

Use this ownership model during autonomous execution to reduce drift:

- `app/core/**`: execution core, metabolism, orchestration, engrams, planning
- `app/nervous_system/**`: messaging, nociception, endocrine signaling, schemas
- `app/rhizome/**`: graph, temporal state, archival, consolidation, native memory boundaries
- `app/sandbox/**`: Firecracker membrane, host bridge, execution audit surface
- `app/sensory/**`: deterministic parsing and ingest
- `app/dashboard/**`: operator-facing observability and control surfaces
- `docs/**`, `README.md`, `PLAN.md`: truthfulness, deployment, architecture, and operating guidance

An agent should avoid widening a task beyond one ownership area unless the task is explicitly a contract or integration task.

## Current Readiness Assessment

### What is already real
- Umbrella application structure across `core`, `nervous_system`, `rhizome`, `sandbox`, `sensory`, and `dashboard`
- OTP supervision and cellular lifecycle scaffolding
- Rust NIF integration for metabolic, sensory, and rhizome functionality
- Tree-sitter parsing in the sensory layer
- initial graph archival and consolidation concepts
- property, subsystem, and chaos-oriented test coverage across much of the repo

### What is currently blocking production readiness
- `core` callers and `rhizome` NIF contracts are inconsistent
- several production-facing paths still return simulated success
- nervous-system transport behavior is unstable and has failing tests
- sandbox execution is not yet a real Firecracker membrane end to end
- dashboard metrics still contain mocked values
- XTDB and service-backed integration behavior is not stable enough
- docs and public artifact references are inconsistent with the actual repo

## Global Environment Prerequisites

These are the baseline assumptions for autonomous work. Any task that needs more than this should declare additional prerequisites inside its phase.

### Local toolchain
- Elixir and Erlang available
- Rust toolchain available
- Mix dependencies installable
- Cargo build available for NIF crates

### Service dependencies
- Memgraph for graph-backed integration work
- XTDB for temporal state validation
- NATS for endocrine/control-plane integration
- Firecracker host support for sandbox hardening work

### Validation baseline
- `mix compile` from [`app/mix.exs`](/home/adrian/Projects/nexical/karyon/app/mix.exs)
- targeted `mix test` runs per app

### Optional but recommended validation tools
- Rust crate tests for changed native code
- service-backed integration runs for Memgraph, XTDB, and NATS
- release boot smoke test for deployment-related changes
- docs build verification for docs-system changes

## Global Validation Commands

Use these as the default validation commands unless a task overrides them.

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix compile
```

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix test
```

Targeted suites:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/nervous_system/test
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sandbox/test
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test
cd /home/adrian/Projects/nexical/karyon/app && mix test apps/sensory/test
```

## Execution Order

Agents should work phases in this order unless a task is marked parallel-safe:

1. Phase 0: Truthfulness And Planning Hygiene
2. Phase 1: Runtime Contract Correction
3. Phase 2: Real Infrastructure Integration
4. Phase 3: Sandbox Membrane Hardening
5. Phase 4: Core Planning And Memory Loops
6. Phase 5: Observability, Releases, And Operations
7. Phase 6: Scale, Resilience, And Production Validation

## Phase Handoff Requirements

Before moving from one phase to the next, confirm:

- all phase exit criteria are met
- all `[doing]` tasks in the phase are resolved to `[done]` or `[blocked]`
- blocked tasks are documented with reason and next dependency
- no temporary compatibility shim remains without an explicit follow-up task
- relevant docs and tests were updated for the phase outcomes

Do not advance phases just because partial code landed. Advance only on validated system state.

## Blocking Conditions

Mark a task `[blocked]` instead of forcing progress when any of the following is true:

- an upstream contract task is incomplete
- an external service or host feature is unavailable
- the task would require inventing architecture that conflicts with `SPEC.md`
- the correct implementation depends on a product, security, or deployment decision not yet made
- the validation environment needed to prove the change is absent

Blocked tasks should include:

- precise missing dependency
- whether the block is local, infrastructure, or design-level
- the next task that can proceed instead

## Standard Progress Note Template

Use this template under each task when recording progress:

```md
Progress notes:
- YYYY-MM-DD: owner/agent - short summary
- Validation: `command` -> result
- Follow-up: short note if any
```

## Standard Task Template

Use this shape for any new task added to the plan:

```md
#### PX.Y Task Name
- Status: `[todo]`
- Scope:
  - concise change list
- Primary files:
  - path list
- Dependencies:
  - upstream task IDs
- Risks:
  - main implementation or validation risks
- Definition of done:
  - concrete completion criteria
- Validation:
  - commands or manual verification
- Progress notes:
  - none yet
```

## Phase 0: Truthfulness And Planning Hygiene

### Goal
Remove ambiguity between implemented behavior and target behavior so later phases are working against an honest baseline.

### Entry criteria
- none

### Exit criteria
- no production-facing path silently returns fake success without explicit marker or config gating
- docs do not reference absent generated artifacts as if they are present
- this plan is usable as the source of truth for execution ordering

### Additional prerequisites
- none

### Tasks

#### P0.1 Audit simulated success paths
- Status: `[todo]`
- Scope:
  - inspect `core`, `sandbox`, and `dashboard` for simulated or placeholder success behavior
  - replace with explicit `{:error, :not_implemented}` or config-gated dev/mock behavior where appropriate
- Primary files:
  - [`app/core/lib/core/motor_driver.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/motor_driver.ex)
  - [`app/core/lib/core/stem_cell.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/stem_cell.ex)
  - [`app/sandbox/lib/sandbox/provisioner.ex`](/home/adrian/Projects/nexical/karyon/app/sandbox/lib/sandbox/provisioner.ex)
  - [`app/dashboard/lib/dashboard/telemetry_bridge.ex`](/home/adrian/Projects/nexical/karyon/app/dashboard/lib/dashboard/telemetry_bridge.ex)
- Dependencies:
  - none
- Risks:
  - simulated behavior may currently be relied on by tests or demo flows
- Definition of done:
  - fake success paths are either removed or explicitly isolated behind mock/dev configuration
  - production code paths fail closed
- Validation:
  - `mix compile`
  - targeted tests for touched apps
- Progress notes:
  - none yet

#### P0.2 Repair documentation references
- Status: `[todo]`
- Scope:
  - reconcile README and docs references to `docs/public/book.md`
  - either generate the artifact or update references to the real docs source/build output
- Primary files:
  - [`README.md`](/home/adrian/Projects/nexical/karyon/README.md)
  - docs config and public references
- Dependencies:
  - none
- Risks:
  - some docs links may point to generated artifacts not currently produced in this repo
- Definition of done:
  - no top-level docs link points to a missing file
  - current-state caveat exists where needed
- Validation:
  - manual link/path verification
- Progress notes:
  - none yet

#### P0.3 Add current-state note to docs
- Status: `[todo]`
- Scope:
  - document target architecture versus implemented runtime
  - clarify which subsystems are MVP, partial, or production-grade
- Dependencies:
  - P0.2 preferred
- Risks:
  - docs can drift again if later phases do not update them with behavior changes
- Definition of done:
  - docs include an honest system-status section
- Validation:
  - docs build or file inspection
- Progress notes:
  - none yet

## Phase 1: Runtime Contract Correction

### Goal
Fix the highest-ROI blocker: incorrect contracts across `core`, `rhizome`, and `nervous_system`.

### Entry criteria
- Phase 0 complete

### Exit criteria
- `core` and `rhizome` agree on NIF return contracts
- XTDB query and submit semantics are coherent
- `nervous_system` baseline test failures are resolved
- no critical code path depends on placeholder query responses

### Additional prerequisites
- `mix compile` baseline
- ability to run targeted tests

### Subphase 1A: Rhizome Contract Redesign

#### P1.1 Define canonical Rhizome NIF return shapes
- Status: `[todo]`
- Scope:
  - define structured Elixir-facing response contracts for:
    - `memgraph_query/1`
    - `xtdb_query/1`
    - `xtdb_submit/2`
    - `bridge_to_xtdb/0`
    - `weaken_edge/1`
  - decide whether rows return maps, lists of maps, or typed structs
- Primary files:
  - [`app/rhizome/lib/rhizome/native.ex`](/home/adrian/Projects/nexical/karyon/app/rhizome/lib/rhizome/native.ex)
  - [`app/rhizome/native/rhizome_nif/src/memgraph.rs`](/home/adrian/Projects/nexical/karyon/app/rhizome/native/rhizome_nif/src/memgraph.rs)
  - [`app/rhizome/native/rhizome_nif/src/xtdb.rs`](/home/adrian/Projects/nexical/karyon/app/rhizome/native/rhizome_nif/src/xtdb.rs)
- Dependencies:
  - Phase 0
- Risks:
  - changing return shapes will affect multiple callers and tests at once
- Definition of done:
  - one explicit contract is chosen and documented in code comments or moduledocs
- Validation:
  - `mix compile`
- Progress notes:
  - none yet

#### P1.2 Implement real Memgraph query result decoding
- Status: `[todo]`
- Scope:
  - replace string-only success responses with structured rows
  - preserve error tuples as explicit `{:error, reason}`
- Dependencies:
  - P1.1
- Risks:
  - row decoding may require a stable serialization strategy across Rust and Elixir
- Definition of done:
  - `memgraph_query/1` returns query data usable by callers
- Validation:
  - `mix test apps/rhizome/test`
- Progress notes:
  - none yet

#### P1.3 Implement coherent XTDB submit/query behavior
- Status: `[todo]`
- Scope:
  - make XTDB submit and query contracts consistent with caller expectations
  - reject malformed input explicitly
- Dependencies:
  - P1.1
- Risks:
  - XTDB caller expectations may need normalization before code changes settle
- Definition of done:
  - XTDB APIs are no longer mixed between ad hoc strings and incompatible JSON assumptions
- Validation:
  - `mix test apps/rhizome/test`
- Progress notes:
  - none yet

### Subphase 1B: Core Caller Alignment

#### P1.4 Update `StemCell` hydration and pruning callers
- Status: `[todo]`
- Scope:
  - update XTDB hydration logic
  - update Rhizome pruning interactions to match real NIF return shapes
- Primary files:
  - [`app/core/lib/core/stem_cell.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/stem_cell.ex)
- Dependencies:
  - P1.2
  - P1.3
- Risks:
  - hydration and pruning are stateful paths that may expose hidden assumptions in tests
- Definition of done:
  - `StemCell` no longer calls incompatible Rhizome APIs
- Validation:
  - `mix test apps/core/test`
- Progress notes:
  - none yet

#### P1.5 Replace placeholder motor planning assumptions
- Status: `[todo]`
- Scope:
  - stop depending on placeholder query values in `MotorDriver`
  - keep planning minimal if necessary, but contract-correct
- Primary files:
  - [`app/core/lib/core/motor_driver.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/motor_driver.ex)
- Dependencies:
  - P1.2
- Risks:
  - temporary fallback behavior can accidentally become permanent if not made explicit
- Definition of done:
  - `MotorDriver` either uses real graph data or returns an explicit not-ready error
- Validation:
  - `mix test apps/core/test`
- Progress notes:
  - none yet

#### P1.6 Correct engram capture/injection assumptions
- Status: `[todo]`
- Scope:
  - make `Engram` operate on actual graph result shapes
  - prevent serialization of placeholder query responses
- Primary files:
  - [`app/core/lib/core/engram.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/engram.ex)
- Dependencies:
  - P1.2
- Risks:
  - engram format changes can create compatibility issues with existing sample artifacts
- Definition of done:
  - engram operations consume real typed graph payloads
- Validation:
  - `mix test apps/core/test`
- Progress notes:
  - none yet

### Subphase 1C: Nervous System Stabilization

#### P1.7 Restrict Synapse transport support
- Status: `[todo]`
- Scope:
  - validate supported protocols explicitly
  - reject unsupported transports like `inproc` if not truly supported by the current implementation
- Primary files:
  - [`app/nervous_system/lib/nervous_system/synapse.ex`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/nervous_system/synapse.ex)
- Dependencies:
  - Phase 0
- Risks:
  - test fixtures may currently assume unsupported protocol behavior
- Definition of done:
  - unsupported protocols do not produce noisy retry loops or crashes
- Validation:
  - `mix test apps/nervous_system/test`
- Progress notes:
  - none yet

#### P1.8 Fix nociception delivery reliability
- Status: `[todo]`
- Scope:
  - fix `PainReceptor` and publish/subscribe timing assumptions
  - ensure the pain-signal path is deterministic enough for tests
- Primary files:
  - [`app/nervous_system/lib/nervous_system/pain_receptor.ex`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/nervous_system/pain_receptor.ex)
  - [`app/nervous_system/lib/nervous_system/synapse.ex`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/nervous_system/synapse.ex)
- Dependencies:
  - P1.7
- Risks:
  - fixing timing issues without clearer contracts can recreate flakiness in a different form
- Definition of done:
  - current `PainReceptor` test failures are resolved
- Validation:
  - `mix test apps/nervous_system/test`
- Progress notes:
  - none yet

#### P1.9 Add transport error telemetry
- Status: `[todo]`
- Scope:
  - emit telemetry for bind failures, unsupported protocols, dropped payloads, and retries
- Dependencies:
  - P1.7
- Risks:
  - telemetry can become noisy if event names and payloads are not standardized
- Definition of done:
  - transport faults become observable
- Validation:
  - targeted nervous-system tests
- Progress notes:
  - none yet

## Phase 2: Real Infrastructure Integration

### Goal
Make the architecture spine function against real services, not just local assumptions.

### Entry criteria
- Phase 1 complete

### Exit criteria
- Memgraph, XTDB, and NATS integration paths are configurable and testable
- dependency health is visible
- service-backed integration tests exist and pass in supported environments

### Additional prerequisites
- Memgraph available
- XTDB available
- NATS available

### Tasks

#### P2.1 Externalize service configuration
- Status: `[todo]`
- Scope:
  - remove hardcoded `127.0.0.1` service assumptions from NIF and runtime code
  - move endpoints and credentials to app config/runtime env
- Primary files:
  - rhizome native client and config files
  - nervous-system connection logic
  - umbrella config
- Dependencies:
  - Phase 1
- Risks:
  - config shape can sprawl if not normalized across apps
- Definition of done:
  - services are configurable without code edits
- Validation:
  - `mix compile`
- Progress notes:
  - none yet

#### P2.2 Add service health and readiness checks
- Status: `[todo]`
- Scope:
  - implement dependency probes for Memgraph, XTDB, and NATS
  - gate startup or mark degraded state explicitly
- Dependencies:
  - P2.1
- Risks:
  - readiness checks can mask real failure modes if they are too shallow
- Definition of done:
  - system reports dependency health before critical work proceeds
- Validation:
  - targeted integration tests
- Progress notes:
  - none yet

#### P2.3 Create real integration suite for Rhizome
- Status: `[todo]`
- Scope:
  - add integration tests for:
    - graph writes
    - query reads
    - XTDB submit/query
    - archival bridge
    - consolidation manager with real state
- Dependencies:
  - P2.1
  - P2.2
- Risks:
  - CI and local environments may diverge without a consistent service harness
- Definition of done:
  - skipped or flaky XTDB behavior is replaced with controlled service-backed validation
- Validation:
  - `mix test apps/rhizome/test`
- Progress notes:
  - none yet

#### P2.4 Create real integration suite for Nervous System
- Status: `[todo]`
- Scope:
  - validate NATS publish/subscribe against a real broker
  - validate ZMQ transport with supported protocols only
- Dependencies:
  - Phase 1
  - P2.1
- Risks:
  - transport tests can become timing-sensitive if contracts remain implicit
- Definition of done:
  - nervous-system tests are grounded in real supported topology
- Validation:
  - `mix test apps/nervous_system/test`
- Progress notes:
  - none yet

#### P2.5 Validate sensory -> rhizome -> core flow
- Status: `[todo]`
- Scope:
  - ingest code via sensory
  - persist to graph
  - query from core
  - verify downstream signaling
- Dependencies:
  - P2.3
  - P1.4
  - P1.5
- Risks:
  - partial success in one layer may hide contract weakness in another
- Definition of done:
  - one end-to-end organism path works against real services
- Validation:
  - targeted integration suite
- Progress notes:
  - none yet

## Phase 3: Sandbox Membrane Hardening

### Goal
Replace the current mock-heavy sandbox path with a real secure execution membrane.

### Entry criteria
- Phase 2 complete

### Exit criteria
- Firecracker boot path is real
- helper pathing and privilege boundaries are correct
- execution results are authentic
- network and mount isolation are enforced and testable

### Additional prerequisites
- Firecracker installed or otherwise available
- host support for TAP and network setup
- helper binary build path understood

### Tasks

#### P3.1 Fix helper binary path resolution
- Status: `[todo]`
- Scope:
  - correct `karyon-net-helper` path resolution from sandbox code
  - avoid brittle relative path assumptions
- Primary files:
  - [`app/sandbox/lib/sandbox/provisioner.ex`](/home/adrian/Projects/nexical/karyon/app/sandbox/lib/sandbox/provisioner.ex)
- Dependencies:
  - Phase 2
- Risks:
  - path fixes can still leave host privilege assumptions unresolved
- Definition of done:
  - sandbox tests no longer fail due to missing helper executable path
- Validation:
  - `mix test apps/sandbox/test`
- Progress notes:
  - none yet

#### P3.2 Remove app-layer privileged cleanup assumptions
- Status: `[todo]`
- Scope:
  - replace `sudo`-dependent cleanup with a safer host integration strategy
  - document the privilege boundary
- Primary files:
  - [`app/sandbox/lib/sandbox/vmm_supervisor.ex`](/home/adrian/Projects/nexical/karyon/app/sandbox/lib/sandbox/vmm_supervisor.ex)
- Dependencies:
  - P3.1
- Risks:
  - host integration can become underspecified if responsibility is not clearly split
- Definition of done:
  - sandbox runtime no longer shells into privileged cleanup as an app concern
- Validation:
  - `mix test apps/sandbox/test`
- Progress notes:
  - none yet

#### P3.3 Implement real Firecracker boot chain
- Status: `[todo]`
- Scope:
  - wire kernel image, rootfs, machine config, and startup flow
  - ensure socket readiness reflects actual VM lifecycle
- Dependencies:
  - P3.1
  - P3.2
- Risks:
  - host-specific Firecracker setup can create hidden environment coupling
- Definition of done:
  - VM startup is not a placeholder task/sleep model
- Validation:
  - integration validation in sandbox environment
- Progress notes:
  - none yet

#### P3.4 Implement real execution telemetry capture
- Status: `[todo]`
- Scope:
  - replace fake success text with real stdout, stderr, and exit-code capture
  - pipe failure states back to the organism
- Dependencies:
  - P3.3
- Risks:
  - output capture can be incomplete if guest process lifecycle is not fully wired
- Definition of done:
  - `capture_output/1` reflects actual guest execution results
- Validation:
  - sandbox integration suite
- Progress notes:
  - none yet

#### P3.5 Enforce mount and network isolation end to end
- Status: `[todo]`
- Scope:
  - verify mount jail constraints
  - verify network isolation on the actual VM execution path
- Dependencies:
  - P3.3
- Risks:
  - audit logic can differ from actual runtime enforcement if tested indirectly
- Definition of done:
  - isolation claims are validated by tests or controlled audits
- Validation:
  - `mix test apps/sandbox/test`
- Progress notes:
  - none yet

## Phase 4: Core Planning And Memory Loops

### Goal
Replace cognitive placeholders with real graph-backed planning and feedback loops.

### Entry criteria
- Phase 3 complete

### Exit criteria
- planning is graph-backed
- execution outcomes feed memory updates
- engram operations reflect real topological data

### Additional prerequisites
- real service-backed Rhizome behavior
- real sandbox execution

### Tasks

#### P4.1 Implement graph-backed motor planning
- Status: `[todo]`
- Scope:
  - replace static dependency lists in `MotorDriver`
  - derive plan steps from real graph topology
- Primary files:
  - [`app/core/lib/core/motor_driver.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/motor_driver.ex)
- Dependencies:
  - P2.3
  - P3.4
- Risks:
  - graph-backed planning can leak semantics into core if abstractions are not carefully placed
- Definition of done:
  - plans are produced from graph state rather than hardcoded sequences
- Validation:
  - `mix test apps/core/test`
- Progress notes:
  - none yet

#### P4.2 Wire execution outcomes back into Rhizome
- Status: `[todo]`
- Scope:
  - persist real success and failure outcomes
  - use them to inform future planning and pruning
- Dependencies:
  - P3.4
  - P1.4
- Risks:
  - event persistence can become lossy if outcome schemas are not standardized
- Definition of done:
  - one execution loop updates memory with real outcomes
- Validation:
  - targeted core and rhizome integration tests
- Progress notes:
  - none yet

#### P4.3 Tighten engram import and export semantics
- Status: `[todo]`
- Scope:
  - define portable engram payload semantics
  - ensure export and import round-trip meaningful structure
- Dependencies:
  - P1.6
  - P2.3
- Risks:
  - backwards compatibility with sample engrams may need explicit migration handling
- Definition of done:
  - engrams are no longer opaque term dumps of ambiguous result shapes
- Validation:
  - `mix test apps/core/test`
- Progress notes:
  - none yet

#### P4.4 Strengthen preflight and metabolic enforcement
- Status: `[todo]`
- Scope:
  - replace placeholder hardware topology checks where feasible
  - better define failure behavior when environment violates constraints
- Dependencies:
  - Phase 2
- Risks:
  - real hardware checks may require environment-specific behavior or elevated access
- Definition of done:
  - preflight is more than a permissive placeholder outside mock mode
- Validation:
  - `mix test apps/core/test`
- Progress notes:
  - none yet

## Phase 5: Observability, Releases, And Operations

### Goal
Make the platform deployable and operable in production.

### Entry criteria
- Phase 4 complete

### Exit criteria
- dashboard uses real telemetry
- release path exists
- operators have health, logs, and runbooks

### Additional prerequisites
- actual runtime telemetry from earlier phases

### Tasks

#### P5.1 Replace dashboard mock metrics
- Status: `[todo]`
- Scope:
  - remove random values for L3 misses and IOPS
  - wire dashboard to actual organism telemetry
- Primary files:
  - [`app/dashboard/lib/dashboard/telemetry_bridge.ex`](/home/adrian/Projects/nexical/karyon/app/dashboard/lib/dashboard/telemetry_bridge.ex)
  - [`app/dashboard/lib/dashboard_web/live/metabolic_live/index.ex`](/home/adrian/Projects/nexical/karyon/app/dashboard/lib/dashboard_web/live/metabolic_live/index.ex)
- Dependencies:
  - Phase 4
- Risks:
  - dashboard can become a misleading partial view if upstream telemetry is incomplete
- Definition of done:
  - dashboard visuals reflect actual signals only
- Validation:
  - dashboard tests and manual telemetry verification
- Progress notes:
  - none yet

#### P5.2 Add release and runtime deployment path
- Status: `[todo]`
- Scope:
  - define production runtime config
  - create deployment and release workflow
- Dependencies:
  - Phase 4
- Risks:
  - runtime assumptions can diverge from development environments if not captured explicitly
- Definition of done:
  - app can be packaged and started in a production-shaped environment
- Validation:
  - release build verification
- Progress notes:
  - none yet

#### P5.3 Add operator health surfaces and runbooks
- Status: `[todo]`
- Scope:
  - add health endpoints, dependency status, and operational docs
- Dependencies:
  - P5.1
  - P5.2
- Risks:
  - operational docs can drift if they are not updated alongside runtime changes
- Definition of done:
  - operators have a supported view into system health and response procedures
- Validation:
  - manual inspection and docs review
- Progress notes:
  - none yet

## Phase 6: Scale, Resilience, And Production Validation

### Goal
Prove the system under real load and fault conditions.

### Entry criteria
- Phase 5 complete

### Exit criteria
- known throughput and recovery targets
- validated chaos and resilience behavior
- documented production operating envelope

### Additional prerequisites
- stable release path
- service-backed integration environment

### Tasks

#### P6.1 Establish baseline performance measurements
- Status: `[todo]`
- Scope:
  - measure spawn rates, messaging throughput, sensory ingest speed, and consolidation cost
- Dependencies:
  - Phase 5
- Risks:
  - measurements can be misleading if environment and workload are not fixed
- Definition of done:
  - a baseline table of throughput and latency exists
- Validation:
  - benchmark outputs recorded in docs or repo artifacts
- Progress notes:
  - none yet

#### P6.2 Run real chaos and recovery validation
- Status: `[todo]`
- Scope:
  - execute apoptosis and supervision recovery against real service-backed runs
- Dependencies:
  - P6.1
- Risks:
  - failure injection can be too shallow if it only targets processes and not backing services
- Definition of done:
  - recovery behavior is measured, not assumed
- Validation:
  - targeted chaos suite
- Progress notes:
  - none yet

#### P6.3 Define production capacity and SLOs
- Status: `[todo]`
- Scope:
  - identify practical operating envelope
  - define recovery and latency expectations
- Dependencies:
  - P6.1
  - P6.2
- Risks:
  - SLOs may be set too early without enough workload realism
- Definition of done:
  - production limits and expectations are documented
- Validation:
  - docs review
- Progress notes:
  - none yet

## Parallel-Safe Work

These tasks can run in parallel once their dependencies are satisfied:

- P0.2 and P0.3
- P1.7 and P1.1
- P2.1 and service prerequisite documentation
- P5.2 and P5.3 after runtime telemetry is stable

Avoid parallel edits on the same files or the same app boundary without an explicit merge plan.

## App-Specific Ready Checklists

## Core
- `[todo]` graph-backed planning replaces static plans
- `[todo]` XTDB hydration uses the real Rhizome contract
- `[todo]` sandbox execution path is authentic
- `[todo]` engram payloads are meaningful and typed
- `[todo]` preflight and metabolic logic enforce real constraints

## Nervous System
- `[todo]` unsupported transports are explicitly rejected
- `[todo]` nociception path is reliable
- `[todo]` transport faults emit telemetry
- `[todo]` ZMQ and NATS integration are tested in supported topologies

## Rhizome
- `[todo]` query results are structured
- `[todo]` XTDB contract is coherent
- `[todo]` service endpoints are configurable
- `[todo]` archival and consolidation are validated with real services

## Sandbox
- `[todo]` helper paths resolve correctly
- `[todo]` Firecracker lifecycle is real
- `[todo]` no app-layer privileged cleanup shortcuts remain
- `[todo]` execution telemetry is authentic
- `[todo]` mount and network isolation are verified

## Sensory
- `[todo]` parse and ingest flows share one authoritative schema
- `[todo]` malformed input handling is robust
- `[todo]` repository-scale ingest performance is measured

## Dashboard
- `[todo]` mocked metrics are removed
- `[todo]` real runtime state is visible
- `[todo]` production endpoint hardening exists

## Docs
- `[todo]` public-book reference issue is resolved
- `[todo]` current-state versus target-state docs exist
- `[todo]` production deployment guidance exists

## Milestone Gates

### Milestone A: Honest Baseline
- Phase 0 complete

### Milestone B: Correct Runtime Spine
- Phase 1 complete

### Milestone C: Real Service-Backed Organism
- Phase 2 complete

### Milestone D: Real Secure Execution
- Phase 3 complete

### Milestone E: Closed Cognitive Loop
- Phase 4 complete

### Milestone F: Production Candidate
- Phase 5 complete

### Milestone G: Production Validated
- Phase 6 complete

## Definition Of Done For The Entire Program

Karyon is production-ready only when:

- critical runtime behavior is real rather than simulated
- app boundaries are stable and integration-tested
- Memgraph, XTDB, NATS, and Firecracker are all exercised in supported environments
- the dashboard and telemetry reflect real system state
- secure execution boundaries are enforced and auditable
- release, deployment, rollback, and operator runbooks exist
- load, fault, and recovery characteristics are measured and documented

## Recommended Immediate Next Task Sequence

Start with:

1. `P0.1`
2. `P0.2`
3. `P1.1`
4. `P1.2`
5. `P1.3`
6. `P1.4`

That sequence removes the biggest sources of false progress and unlocks the largest amount of real functionality across the current codebase.
