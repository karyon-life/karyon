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
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Replaced placeholder success in `Core.MotorDriver`, `Core.StemCell`, and `Sandbox.Provisioner.capture_output/1` with explicit not-ready errors or mock-gated behavior.
    - Replaced randomized dashboard telemetry values with live BEAM/native readings, surfacing unavailable metrics honestly instead of fabricating values.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app && mix compile`
      - `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/stem_cell_test.exs test/core/motor_driver_test.exs`
      - `cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/provisioner_test.exs`

#### P0.2 Repair documentation references
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Updated top-level README links to point to real repo paths instead of missing `docs/public/book.md`, `file://` links, and an absent local walkthrough artifact.
    - Made the docs-site book download button conditional on the generated file actually existing.
    - Validation run:
      - manual path verification against checked-in files
      - `cd /home/adrian/Projects/nexical/karyon/app && mix compile`

#### P0.3 Add current-state note to docs
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Added an honest current-state section to the root README, docs README, and docs landing page clarifying which parts of Karyon are implemented versus still being hardened.
    - Validation run:
      - file inspection of `README.md`, `docs/README.md`, and `docs/src/content/docs/index.mdx`

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
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Split the raw Rustler boundary into `Rhizome.Raw` and a public `Rhizome.Native` wrapper that now defines and documents canonical Elixir-facing contracts.
    - Standardized public shapes to decoded row lists for `memgraph_query/1` and `xtdb_query/1`, metadata maps for `xtdb_submit/2`, `bridge_to_xtdb/0`, and `weaken_edge/1`, and explicit `{:error, reason}` failures.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app && mix compile`

#### P1.2 Implement real Memgraph query result decoding
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Reworked the native Memgraph client to execute queries as row streams and serialize decoded rows as JSON instead of returning string-only success markers.
    - `Rhizome.Native.memgraph_query/1` now returns real row data, including aggregate maps such as `%{"count" => ...}` and graph payload rows used by `Engram`.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app/rhizome && mix test`

#### P1.3 Implement coherent XTDB submit/query behavior
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Normalized XTDB submit/query inputs to JSON payloads and normalized successful responses to decoded Elixir terms instead of ad hoc raw strings.
    - Added explicit rejection for malformed query/document inputs through the wrapper contract and updated XTDB tests to use structured query payloads.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app/rhizome && mix test`

### Subphase 1B: Core Caller Alignment

#### P1.4 Update `StemCell` hydration and pruning callers
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Replaced the old XTDB hydration assumption in `StemCell` with structured XTDB query input and tolerant belief extraction from decoded query results.
    - Kept pruning interactions aligned with the new `weaken_edge/1` contract while preserving fail-closed behavior when Rhizome data is absent.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/stem_cell_test.exs test/core/motor_driver_test.exs test/core/engram_test.exs`
      - Broader `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core` was started but is dominated by long-running scale/stress coverage outside this contract slice, so focused contract tests were used for task validation.

#### P1.5 Replace placeholder motor planning assumptions
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - `Core.MotorDriver` no longer depends on placeholder graph-step data. It now requires a real Rhizome attractor lookup and returns `{:error, :graph_planning_not_ready}` until graph-backed planning is implemented.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/motor_driver_test.exs`

#### P1.6 Correct engram capture/injection assumptions
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Updated `Core.Engram` to capture decoded graph rows and import from explicit `%{"n" => ..., "m" => ...}` row shapes rather than ambiguous nested list placeholders.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/engram_test.exs`

### Subphase 1C: Nervous System Stabilization

#### P1.7 Restrict Synapse transport support
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Restricted `NervousSystem.Synapse` to explicit supported transport parsing, returning `{:unsupported_protocol, ...}` for unsupported schemes instead of retry storms.
    - Updated property tests to validate supported TCP topology and added an explicit unsupported-transport assertion.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app/nervous_system && mix test test/nervous_system/synapse_test.exs test/nervous_system/synapse_property_test.exs test/nervous_system/pain_receptor_test.exs`

#### P1.8 Fix nociception delivery reliability
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Fixed `PainReceptor` telemetry attachment lifetime by using per-process handler ids and detaching them on terminate.
    - Fixed `Synapse.start_link/1` to honor GenServer registration options such as `:name`, which stabilized the test setup and delivery path.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app/nervous_system && mix test test/nervous_system/synapse_test.exs test/nervous_system/synapse_property_test.exs test/nervous_system/pain_receptor_test.exs`

#### P1.9 Add transport error telemetry
- Status: `[done]`
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
  - 2026-03-16 / Codex
    - Added telemetry emission for transport init failures, unsupported protocols, bind retries, bind/connect failures, send failures, and receiver shutdown.
    - Validation run:
      - `cd /home/adrian/Projects/nexical/karyon/app/nervous_system && mix test test/nervous_system/synapse_test.exs test/nervous_system/synapse_property_test.exs test/nervous_system/pain_receptor_test.exs`

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
- Status: `[done]`
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
  - 2026-03-16: Codex - centralized Memgraph, XTDB, and NATS endpoints under `:karyon, :services`; removed hardcoded service URLs from `NervousSystem.Endocrine`, `Rhizome.Native`/`Rhizome.Raw`, and the Sensory NIF boundary.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/nervous_system && mix test test/nervous_system/endocrine_test.exs` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sensory && mix test test/sensory/native_test.exs` -> passed

#### P2.2 Add service health and readiness checks
- Status: `[done]`
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
  - 2026-03-16: Codex - added `Core.ServiceHealth` with explicit Memgraph, XTDB, and NATS probes and gated service-backed harness flows in `Core.TestHarness` so critical integration paths fail closed on degraded dependencies.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/service_health_test.exs` -> passed

#### P2.3 Create real integration suite for Rhizome
- Status: `[done]`
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
  - 2026-03-16: Codex - added `app/rhizome/test/rhizome/service_integration_test.exs` covering real Memgraph writes/reads, XTDB submit/query, archival bridge, and consolidation-manager pruning with controlled service probing.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/rhizome && mix test test/rhizome/service_integration_test.exs --include external` -> failed; Memgraph-backed checks passed, but XTDB `/tx` and `/query` calls intermittently returned `channel closed` and `connection reset by peer`.
  - 2026-03-16: Codex - verified root cause of the XTDB failures: `compose.yml` launches `ghcr.io/xtdb/xtdb:latest`, which is XTDB `2.1.0`; the running container exposes health on `8080` and PG-wire on `5432`, while the Rhizome client still targets the XTDB v1 HTTP `/tx` and `/query` API on `3000`.
  - Validation: `curl -i --max-time 5 http://127.0.0.1:3000/` -> `Recv failure: Connection reset by peer`
  - Validation: `curl -i --max-time 5 http://127.0.0.1:3000/status` -> `Recv failure: Connection reset by peer`
  - Validation: `docker logs --tail 100 karyon_xtdb` -> XTDB `2.1.0`, health server on `8080`, PG-wire on `5432`
  - Validation: `docker exec karyon_xtdb sh -lc 'curl -i --max-time 5 http://127.0.0.1:8080/'` -> XTDB Healthz HTML page
  - Validation: `docker exec karyon_xtdb sh -lc 'curl -i --max-time 5 http://127.0.0.1:3000/'` -> connection refused inside container
  - 2026-03-16: Codex - exposed XTDB `5432` and `8080` in `compose.yml` so the actual v2 service surface is inspectable during the eventual contract migration or harness pinning work.
  - 2026-03-16: Codex - migrated the public XTDB path to XTDB v2 semantics by replacing the v1 HTTP client with an Elixir `Postgrex` adapter in `Rhizome.Xtdb`, switching the default XTDB config to `postgres://127.0.0.1:5432/xtdb`, recreating the XTDB container with `5432` exposed, and reimplementing `Rhizome.Native.bridge_to_xtdb/0` on the Elixir side while preserving the existing public return shapes.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix deps.get` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/rhizome && mix test test/rhizome/bitemporal_test.exs` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/rhizome && mix test test/rhizome/service_integration_test.exs --include external` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix test apps/rhizome/test` -> Rhizome tests passed; umbrella path emitted path-mismatch noise in other apps after the Rhizome run, so the effective validation was the Rhizome app suite plus the external service suite.

#### P2.4 Create real integration suite for Nervous System
- Status: `[done]`
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
  - 2026-03-16: Codex - converted NATS broker tests to explicit external integrations with broker-availability gating and kept supported TCP-only ZMQ transport validation in the standard suite.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/nervous_system && mix test test/nervous_system/endocrine_gradient_test.exs --include external` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/nervous_system && mix test test/nervous_system/synapse_test.exs test/nervous_system/synapse_property_test.exs` -> passed

#### P2.5 Validate sensory -> rhizome -> core flow
- Status: `[done]`
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
  - 2026-03-16: Codex - not started because `P2.3` remains blocked on unstable XTDB-backed Rhizome integration, which is a declared prerequisite for end-to-end service-backed flow validation.
  - 2026-03-16: Codex - tightened existing XTDB-dependent integration tests so they are tagged `:external` and no longer imply default-suite coverage while the XTDB service contract remains mismatched.
  - 2026-03-16: Codex - strengthened `app/core/test/platform_integration_test.exs` so the end-to-end path now ingests code via `Sensory.Native`, persists and bridges graph state through Rhizome, hydrates a new `Core.StemCell` lineage from XTDB v2, and verifies downstream endocrine signaling by driving the cell into torpor from a real metabolic spike.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/platform_integration_test.exs --include external` -> passed

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
- Status: `[done]`
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
  - 2026-03-16: Codex - replaced brittle helper-path guessing with explicit `Sandbox.Provisioner.helper_path/0` resolution over sandbox config, environment, `$PATH`, and known app-root build outputs; missing helpers now return `{:error, :net_helper_not_found}` instead of raising.
  - 2026-03-16: Codex - added sandbox test coverage for config-driven helper resolution and retained failure-path coverage through `verify_network/1`.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/provisioner_test.exs test/sandbox/security_audit_test.exs` -> passed

#### P3.2 Remove app-layer privileged cleanup assumptions
- Status: `[done]`
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
  - 2026-03-16: Codex - removed direct `sudo ip ...` cleanup from `Sandbox.VmmSupervisor`; tap-device teardown is now delegated exclusively to `karyon-net-helper` via the existing host-boundary resolution path.
  - 2026-03-16: Codex - documented the privilege boundary in `Sandbox.VmmSupervisor` and added a focused test proving cleanup invokes the configured helper instead of shelling into privileged app-layer commands.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/provisioner_test.exs test/sandbox/security_audit_test.exs` -> passed

#### P3.3 Implement real Firecracker boot chain
- Status: `[done]`
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
  - 2026-03-16: Codex - wired explicit Firecracker runtime prerequisite resolution into the non-mock sandbox path. `Sandbox.Firecracker.boot_requirements/0` now requires a real Firecracker binary, kernel image, and rootfs path; `Sandbox.Provisioner.provision_vm/1` now re-enables `set_boot_source/3` and `set_drive/3` and refuses to proceed without those prerequisites.
  - 2026-03-16: Codex - updated `Sandbox.VmmSupervisor.start_vmm/3` to use the resolved Firecracker binary instead of a bare `"firecracker"` shell assumption, and added focused test coverage for fail-closed prerequisite handling.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/firecracker_test.exs test/sandbox/provisioner_test.exs` -> passed
  - 2026-03-16: Codex - verified a real Firecracker binary now exists at `/usr/local/bin/firecracker` and pinned that path into `app/config/config.exs` via `:sandbox, :firecracker_binary`.
  - Validation: `ls -l /usr/local/bin/firecracker` -> present and executable
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - 2026-03-16: Codex - verified host kernel and rootfs artifacts were provided at `/opt/karyon/firecracker/vmlinux` and `/opt/karyon/firecracker/rootfs.ext4`.
  - 2026-03-16: Codex - built the host network helper, broadened sandbox helper resolution to accept the actual built artifact name `net_helper`, and tightened the helper so failed TAP/iptables setup exits non-zero instead of reporting false success.
  - 2026-03-16: Codex - executed the real non-mock provision path with `KARYON_MOCK_HARDWARE=0`, `KARYON_FIRECRACKER_KERNEL=/opt/karyon/firecracker/vmlinux`, `KARYON_FIRECRACKER_ROOTFS=/opt/karyon/firecracker/rootfs.ext4`, and `KARYON_NET_HELPER=/home/adrian/Projects/nexical/karyon/app/sandbox/native/net_helper/target/release/net_helper`. Firecracker started successfully and bound `/tmp/firecracker-vm-3.socket`, but host networking failed before a valid isolated VM launch completed.
  - Validation: `env KARYON_MOCK_HARDWARE=0 KARYON_FIRECRACKER_KERNEL=/opt/karyon/firecracker/vmlinux KARYON_FIRECRACKER_ROOTFS=/opt/karyon/firecracker/rootfs.ext4 KARYON_NET_HELPER=/home/adrian/Projects/nexical/karyon/app/sandbox/native/net_helper/target/release/net_helper mix run -e 'IO.inspect(Sandbox.Provisioner.provision_vm("/tmp/test_plan.json"))'` -> Firecracker API socket started, then provisioning failed with `{:error, :network_setup_failed}`
  - Blocker: infrastructure - host TAP and firewall setup are not permitted for the helper in the current environment, and the configured bridge device `karyon0` does not exist.
  - Validation: helper output during real run -> `ioctl(TUNSETIFF): Operation not permitted`
  - Validation: helper output during real run -> `iptables ... Permission denied (you must be root)`
  - Validation: helper output during real run -> `argument "karyon0" is wrong: Device does not exist`
  - 2026-03-16: Codex - verified `/usr/local/bin/karyon-net-helper` now has `cap_net_admin=ep` and `karyon0` exists, then reran the real non-mock provision path. Firecracker still started and bound its API socket, but TAP and iptables setup failed with the same permission errors.
  - Validation: `getcap /usr/local/bin/karyon-net-helper && ip link show karyon0` -> helper has `cap_net_admin=ep`, bridge exists
  - Validation: `env KARYON_MOCK_HARDWARE=0 KARYON_FIRECRACKER_KERNEL=/opt/karyon/firecracker/vmlinux KARYON_FIRECRACKER_ROOTFS=/opt/karyon/firecracker/rootfs.ext4 KARYON_NET_HELPER=/usr/local/bin/karyon-net-helper mix run -e 'IO.inspect(Sandbox.Provisioner.provision_vm("/tmp/test_plan.json"))'` -> Firecracker API socket started, then provisioning failed with `{:error, :network_setup_failed}`
  - Blocker refinement: implementation/design - the helper currently shells out to `ip` and `iptables`, and the helper's file capability does not grant those child executables the needed privilege. To complete the real boot chain, the helper must perform TAP and firewall work directly (netlink/nftables or equivalent) or be executed through a truly privileged host boundary.
  - 2026-03-16: Codex - refactored `app/sandbox/native/net_helper/src/main.rs` so the helper now manages TAP lifecycle directly with Linux ioctls instead of spawning `ip` or `iptables`. The helper now creates persistent TAP devices through `/dev/net/tun`, attaches them to the requested bridge with `SIOCBRADDIF`, brings them up with `SIOCSIFFLAGS`, and tears them down by clearing `TUNSETPERSIST`.
  - 2026-03-16: Codex - replaced the old iptables-based verification path with structural bridge isolation checks. `verify` now requires the tap to exist, be up, be attached to a bridge, the bridge to contain only `tap-vm-*` members, and the bridge to have no IPv4 route in `/proc/net/route`.
  - 2026-03-16: Codex - stabilized the sandbox test suite after the stricter helper validation by making the mock-network audit test set `KARYON_MOCK_HARDWARE` explicitly.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox/native/net_helper && cargo build --release` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/firecracker_test.exs test/sandbox/provisioner_test.exs test/sandbox/security_audit_test.exs` -> passed
  - 2026-03-16: Codex - after the rebuilt helper was reinstalled onto `/usr/local/bin/karyon-net-helper` with `CAP_NET_ADMIN`, the real non-mock provision path moved past host networking and exposed Firecracker API drift in the Elixir client. `init_vmm/1` was corrected to use `GET /version`, and the network-interface payload was aligned with Firecracker 1.15 by removing the unsupported `allow_mmds_requests` field.
  - Validation: `getcap /usr/local/bin/karyon-net-helper` -> `/usr/local/bin/karyon-net-helper cap_net_admin=ep`
  - Validation: `ip link show karyon0` -> bridge exists and is up for host use
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/firecracker_test.exs test/sandbox/provisioner_test.exs test/sandbox/security_audit_test.exs` -> passed
  - Validation: `env KARYON_MOCK_HARDWARE=0 KARYON_FIRECRACKER_KERNEL=/opt/karyon/firecracker/vmlinux KARYON_FIRECRACKER_ROOTFS=/opt/karyon/firecracker/rootfs.ext4 KARYON_NET_HELPER=/usr/local/bin/karyon-net-helper mix run -e 'IO.inspect(Sandbox.Provisioner.provision_vm("/tmp/test_plan.json"))'` -> Firecracker initialized, accepted machine/network/boot/drive configuration, returned `204` on `InstanceStart`, and `Sandbox.Provisioner.provision_vm/1` completed with `{:ok, "vm-3042"}`

#### P3.4 Implement real execution telemetry capture
- Status: `[done]`
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
  - 2026-03-17: Codex - replaced the placeholder `capture_output/1` path with real file-backed runtime telemetry. `Sandbox.Provisioner` now registers per-VM runtime metadata, persists stdout/stderr paths in `Sandbox.RuntimeRegistry`, and `capture_output/1` returns actual captured output, status, and exit code instead of fabricated success text.
  - 2026-03-17: Codex - refactored `Sandbox.VmmSupervisor` so Firecracker launches with stdout and stderr redirected into per-VM files, stores the supervised task pid in runtime metadata, and reports non-zero exits to `PainReceptor`.
  - 2026-03-17: Codex - repointed `Sandbox.Console` from a nonexistent placeholder pipe to the real stdout stream and changed it to tail append-only files instead of only working against FIFOs, so VM boot/runtime failures can flow back into the organism.
  - 2026-03-17: Codex - added focused coverage for `capture_output/1` returning persisted stdout/stderr/exit_code and for the missing-runtime error path.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/firecracker_test.exs test/sandbox/provisioner_test.exs test/sandbox/security_audit_test.exs` -> passed
  - Validation: `env KARYON_MOCK_HARDWARE=0 KARYON_FIRECRACKER_KERNEL=/opt/karyon/firecracker/vmlinux KARYON_FIRECRACKER_ROOTFS=/opt/karyon/firecracker/rootfs.ext4 KARYON_NET_HELPER=/usr/local/bin/karyon-net-helper mix run -e 'case Sandbox.Provisioner.provision_vm("/tmp/test_plan.json") do {:ok, vm_id} -> Process.sleep(500); IO.inspect({vm_id, Sandbox.Provisioner.capture_output(vm_id)}) ; {:error, reason} -> IO.inspect({:error, reason}) end'` -> returned `{:ok, %{mode: :firecracker, status: :running, stdout: ...guest boot/runtime log..., stderr: "", exit_code: nil, vm_id: "vm-1410"}}`
  - Residual risk: host-side orphan tap cleanup is still imperfect when a VM is terminated outside the normal runtime path; that does not block real telemetry capture, but it should be addressed during Phase 3 isolation hardening.

#### P3.5 Enforce mount and network isolation end to end
- Status: `[done]`
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
  - 2026-03-17: Codex - hardened mount-jail enforcement in `Sandbox.Provisioner`. `verify_mount_safety/1` now rejects sibling-prefix escapes like `~/.karyon/sandboxes_evil/...`, and `verify_mount_isolation/1` rejects symlink-backed mount targets even when they live under the sandbox root.
  - 2026-03-17: Codex - extended the privileged helper cleanup path to detach TAP devices from the bridge before clearing persistence, so network teardown can remove VM interfaces instead of leaving orphaned `tap-vm-*` devices behind.
  - 2026-03-17: Codex - fixed the runtime cleanup boundary so VMM teardown stops the live Firecracker process before helper cleanup runs. `Sandbox.VmmSupervisor` now attempts managed runtime shutdown and falls back to a targeted `pkill` by `--api-sock` path to avoid leaked VMs keeping TAP devices busy.
  - 2026-03-17: Codex - added focused test coverage for sibling-prefix jail bypasses, symlink mount rejection, and the real external cleanup path that provisions a non-mock VM and asserts its tap device is absent after cleanup.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox/native/net_helper && cargo build --release` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/firecracker_test.exs test/sandbox/provisioner_test.exs test/sandbox/security_audit_test.exs test/sandbox/security_isolation_test.exs` -> passed after test env isolation fixes
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/sandbox && mix test test/sandbox/security_isolation_test.exs --include external` -> passed
  - Validation: `pgrep -af firecracker` -> no remaining Firecracker processes after cleanup
  - Validation: `ls /sys/class/net` -> no remaining `tap-vm-*` interfaces after cleanup

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
- Status: `[done]`
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
  - 2026-03-17: Codex - replaced the `MotorDriver.fetch_causal_chain/1` placeholder with a real Memgraph traversal over `(:SuperNode)<-[:MEMBER_OF]-(:TaskNode|:Cell|:ASTNode|...)`. Planning now derives ordered step maps from actual Rhizome topology instead of hardcoded failure returns.
  - 2026-03-17: Codex - normalized graph member nodes into stable motor-plan steps with `id`, `action`, `params`, and `predicted_outcome`, while preserving the existing structured plan envelope used by `dispatch_plan/2`.
  - 2026-03-17: Codex - aligned the stale tier-5 core test with the structured plan contract and added a real external planning test that seeds a `SuperNode` plus `MEMBER_OF`/`SYNAPSE` topology in Memgraph and verifies ordered step derivation.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/motor_driver_test.exs test/core/tier5_global_test.exs` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/motor_driver_test.exs --include external` -> passed

#### P4.2 Wire execution outcomes back into Rhizome
- Status: `[done]`
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
  - 2026-03-17: Codex - added `Rhizome.Memory.submit_execution_outcome/1` as the canonical Phase 4 outcome write path. It persists normalized execution-outcome documents into XTDB and projects a summary `(:Cell)-[:EMITTED]->(:ExecutionOutcome)` edge back into Memgraph.
  - 2026-03-17: Codex - wired `Core.StemCell.handle_call({:execute, ...})` to persist both success and failure outcomes after motor dispatch without changing the caller-visible reply contract. Outcome records now include cell identity, action, executor, vm id, params, belief snapshot, status, exit code, and result/error payloads.
  - 2026-03-17: Codex - added a stubbed unit test proving `StemCell.execute` emits an execution-outcome persistence request, a real external core test proving a `StemCell` execution stores an outcome in XTDB, and a real Rhizome test proving `submit_execution_outcome/1` is queryable from XTDB.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/stem_cell_test.exs` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/rhizome && mix test test/rhizome_test.exs --include external` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/stem_cell_test.exs --include external` -> passed

#### P4.3 Tighten engram import and export semantics
- Status: `[done]`
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
  - 2026-03-17: Codex - replaced the opaque Erlang-term engram dump with a versioned portable envelope in `Core.Engram`. Captured engrams now contain explicit node and edge payloads, format/version metadata, counts, and a SHA-256 digest, then serialize as gzipped JSON instead of unsafe `binary_to_term` blobs.
  - 2026-03-17: Codex - tightened import semantics to validate engram name safety, payload schema, and digest integrity before any Rhizome mutation. `inject/1` now reconstructs nodes and typed edges from explicit payload semantics rather than collapsing everything into anonymous `KNOWLEDGE_LINK` edges.
  - 2026-03-17: Codex - added focused tests for invalid names, malformed payload rejection, valid schema import, and preserved the higher-level capture/inject cycle test against the new portable format.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/engram_test.exs test/core/tier5_global_test.exs` -> passed

#### P4.4 Strengthen preflight and metabolic enforcement
- Status: `[done]`
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
  - 2026-03-17: Codex - replaced the permissive non-mock memory-channel placeholder in `Core.Preflight` with actual topology evidence checks. Preflight now accepts either EDAC controller presence under `/sys/devices/system/edac/mc` or NUMA node memory evidence from `/sys/devices/system/node/node0/meminfo`, and it supports explicit test/runtime injection of the native module and filesystem probes.
  - 2026-03-17: Codex - tightened scheduler and NUMA enforcement by routing preflight through injected native-module reads, preserving hard failure semantics outside mock mode while allowing explicit `mock_hardware?: false` coverage under the core test harness.
  - 2026-03-17: Codex - strengthened `Core.MetabolicDaemon` boot behavior so failed preflight now either stops startup in strict mode or starts in a degraded metabolic state with elevated pressure when strict mode is disabled. Pressure calculation now folds in preflight degradation and high IOPS pressure instead of relying only on run-queue deltas.
  - 2026-03-17: Codex - added focused tests for memory-topology failure, NUMA violation failure, degraded-start behavior, strict preflight refusal, and high-IOPS pressure elevation.
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app && mix compile` -> passed
  - Validation: `cd /home/adrian/Projects/nexical/karyon/app/core && mix test test/core/preflight_test.exs test/core/metabolic_daemon_test.exs test/core/metabolic_stress_test.exs` -> passed

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
