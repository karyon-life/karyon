# STDP Backend Nervous System Upgrade Prompt

Use this prompt to direct an implementation model to perform the STDP backend refactor described in [`chat2.xml`](/home/adrian/Projects/nexical/karyon/chat2.xml): upgrade `app/nervous_system` from a generic nociception bus into a lock-free, OTP-compliant STDP pathway that accepts operator-induced pain over NATS, maintains a monotonic eligibility trace, and emits typed correction events into `Core.StemCell`.

## Prompt

You are refactoring the Karyon repository at `/home/adrian/Projects/nexical/karyon`.

Your objective is to execute the STDP backend upgrade described in `chat2.xml`: extend the nervous system so operator-induced nociception can be serialized over the NATS control plane, correlated against recent motor actions inside an eligibility trace, and translated into highly typed STDP prediction errors for `Core.StemCell`.

### Architectural intent

- Treat `chat2.xml` as the architectural source of truth for this refactor, especially the sections discussing operator-induced nociception, STDP coordination, eligibility traces, and pruning of failed sensory-to-motor pathways.
- This is not an external NLP or orchestration feature. It is a backend plasticity upgrade for biologically framed learning, using lock-free OTP processes and typed transport contracts.
- Preserve the Karyon constraints in `AGENTS.md` and `GEMINI.md`: biology first, actor isolation, no centralized mutable state, no monolithic orchestration, and no weakening of OTP fault tolerance or metabolic governance.

### Important repo facts you must honor

- [`app/nervous_system/priv/proto/metabolic_spike.proto`](/home/adrian/Projects/nexical/karyon/app/nervous_system/priv/proto/metabolic_spike.proto) currently defines `metric_type`, `value`, `threshold`, `timestamp`, and string `severity`.
- [`app/nervous_system/priv/proto/prediction_error.proto`](/home/adrian/Projects/nexical/karyon/app/nervous_system/priv/proto/prediction_error.proto) currently defines `type`, `message`, `timestamp`, `metadata`, and `cell_id`, but has no explicit source field and no float severity field.
- [`app/nervous_system/lib/nervous_system/application.ex`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/nervous_system/application.ex) currently supervises only `NervousSystem.PainReceptor` under `:one_for_one`.
- [`app/nervous_system/lib/nervous_system/pain_receptor.ex`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/nervous_system/pain_receptor.ex) currently emits generic `PredictionError` records with metadata-based severity and source strings.
- [`app/core/lib/core/stem_cell.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/stem_cell.ex) currently decodes metabolic spikes using `"high"`, `"medium"`, and `"low"` string severity branches and does not yet keep an explicit `motor_action_id` / STDP eligibility trace correlation surface.
- [`app/nervous_system/lib/nervous_system/endocrine.ex`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/nervous_system/endocrine.ex) is the existing NATS transport boundary. Use it rather than bypassing the control plane.

### Non-negotiable runtime constraints

- Preserve OTP `:one_for_one` supervision in `NervousSystem.Application`.
- Keep the STDP path actor-oriented and lock-free. Use GenServer-local state only.
- Use `System.monotonic_time(:millisecond)` for trace timestamps, decay, and correlation. Do not use wall-clock time for eligibility windows.
- Do not introduce ETS, global registries, mutexes, shared mutable buffers, or central coordination bottlenecks.
- Do not bypass `NervousSystem.Endocrine` with ad hoc NATS clients from unrelated modules.
- Do not weaken or remove existing `Core.MetabolicDaemon` constraints to make the migration easier.

### Required protobuf changes

Update both protobuf schemas so the transport layer can represent operator-induced nociception and continuous severity.

1. Update `app/nervous_system/priv/proto/metabolic_spike.proto` to carry:
   - an explicit source field that can represent `:operator_induced` at the Elixir boundary
   - a continuous float severity field constrained by the implementation to `0.0..1.0`
2. Update `app/nervous_system/priv/proto/prediction_error.proto` to carry:
   - an explicit source field that can represent `:operator_induced` at the Elixir boundary
   - a continuous float severity field constrained by the implementation to `0.0..1.0`
3. Make the schema migration decision-complete:
   - you may use a protobuf enum or canonical string on the wire
   - after decode, the Elixir-facing representation must normalize the operator source to `:operator_induced`
   - direct consumers must migrate to numeric severity handling rather than preserving a parallel string-only severity path
4. Update generated/protox-facing consumers and tests accordingly, including:
   - `NervousSystem.PainReceptor`
   - `Core.StemCell`
   - `Core.MetabolicDaemon`
   - direct protobuf tests in `app/nervous_system/test`

### New STDP coordinator

Scaffold a new OTP GenServer named `Sensory.STDPCoordinator`.

#### Ownership and supervision

- Keep the requested module name `Sensory.STDPCoordinator`.
- Supervise it from `NervousSystem.Application` under the existing `:one_for_one` strategy.
- Do not move supervision ownership into `app/sensory`; this backend upgrade belongs to the nervous system transport/control plane.

#### Required coordinator contract

The coordinator must expose a bounded GenServer contract for:

- registering active motor traces keyed by `motor_action_id`
- receiving operator nociception from the NATS bus
- pruning expired traces opportunistically during normal message handling
- emitting typed STDP correction events to `Core.StemCell`

### Eligibility trace requirements

Implement an internal `Eligibility Trace` buffer inside `Sensory.STDPCoordinator`.

Requirements:

- hold active `motor_action_id` entries for a decaying 4-second default window
- allow configurability only if the configured window stays bounded inside the requested 3-to-5 second range
- timestamp each trace using `System.monotonic_time(:millisecond)`
- keep trace state in the GenServer only
- prune expired traces opportunistically during casts, calls, and nociception handling rather than relying on external locks or shared timers

Each active trace must carry enough data to emit a typed STDP event later. At minimum, preserve:

- `motor_action_id`
- associated `sensory_id`
- monotonic activation timestamp
- any lineage or routing metadata required to deliver the resulting event to the correct `Core.StemCell`

### Operator nociception path

Use NATS as the source of operator-induced pain.

Requirements:

- define a dedicated NATS subject for operator nociception
- use `operator.nociception` as the default subject
- subscribe through `NervousSystem.Endocrine`
- decode the operator nociception payload through the updated protobuf contract rather than raw maps or opaque terms
- require severity validation so `0.0 <= severity <= 1.0`
- choose an explicit invalid-severity policy and implement it consistently

Use this policy for invalid severity values:

- reject invalid values and drop the event with bounded logging
- do not silently clamp or mutate out-of-range severity at runtime

### STDP correlation behavior

Implement the coordinator logic so it:

1. intercepts operator nociception signals arriving from the NATS bus
2. normalizes their source to `:operator_induced`
3. prunes expired traces using monotonic time
4. correlates the nociception against still-active eligibility traces
5. emits one typed event per surviving match as:
   - `{:stdp_prediction_error, sensory_id, severity}`

Do not emit generic untyped error tuples. The coordinator must produce the explicit STDP tuple shape above.

If the current runtime does not already provide a stable `sensory_id` mapping for active motor actions, add the smallest coherent state extension needed to make that mapping explicit.

### Core stem cell integration

Rewrite `Core.StemCell` so it can participate in STDP correlation and pruning without introducing a broker process.

Requirements:

- retain the currently executing `ExecutionIntent.id` as the active `motor_action_id`
- preserve or derive the associated `sensory_id` needed for later STDP pruning
- add first-class handling for `{:stdp_prediction_error, sensory_id, severity}`
- keep this distinct from the existing generic `PredictionError` decode path
- route the STDP event into the existing learning and memory path with explicit typed handling

The implementation must not assume that `last_active_motor_intent` or `motor_action_id` already exists in state. Introduce the smallest coherent runtime state needed to support STDP correlation.

### Metabolic severity migration

This refactor is a hard migration for direct consumers.

Requirements:

- replace string-severity branching in direct protobuf consumers with numeric severity handling
- update `Core.StemCell` metabolic pressure logic so numeric severity continues to drive torpor and pressure transitions
- preserve the role and constraints of `Core.MetabolicDaemon`
- do not leave permanent parallel `"high" | "medium" | "low"` branches in direct protobuf handling

If thresholds are needed for metabolic handling, define them explicitly in code and tests rather than inferring them implicitly from strings.

### Explicit prohibitions

The implementation must forbid:

- external NLP APIs
- pre-trained tokenizers
- wall-clock time for eligibility decay
- ETS or process-external trace storage
- parser wrappers hidden behind new transport modules
- bypassing `NervousSystem.Endocrine` with raw NATS or opaque transport calls from the coordinator

If the implementation introduces shared mutable trace state or relies on `System.system_time/1` for STDP correlation, it is incorrect.

### Test and verification requirements

Update the nervous-system and core test surfaces so they match the new STDP backend.

At minimum:

1. Rewrite protobuf tests to verify:
   - `MetabolicSpike` round-trips with explicit source and float severity
   - `PredictionError` round-trips with explicit source and float severity
   - `:operator_induced` is representable at the Elixir boundary
   - invalid severity values are rejected according to the chosen policy
2. Add or rewrite nervous-system tests to verify:
   - `Sensory.STDPCoordinator` starts under `NervousSystem.Application`
   - the eligibility trace retains active entries for the monotonic 4-second default window
   - expired traces are pruned and do not emit STDP events
   - operator nociception arriving on `operator.nociception` produces `{:stdp_prediction_error, sensory_id, severity}` only for traces still inside the window
   - the coordinator remains state-local and lock-free
3. Rewrite direct pain and endocrine tests as needed to verify:
   - `NervousSystem.PainReceptor` emits updated protobuf payloads
   - `NervousSystem.Endocrine` remains the NATS transport boundary used by the STDP path
4. Rewrite core tests to verify:
   - `Core.StemCell` records active `ExecutionIntent.id` as a `motor_action_id` correlation surface
   - `Core.StemCell` handles `{:stdp_prediction_error, sensory_id, severity}` distinctly from generic prediction errors
   - numeric metabolic severity still drives torpor and pressure transitions correctly after migration
5. Run a repo search and confirm:
   - no direct string-only severity assumptions remain in `app/nervous_system` protobuf consumers
   - STDP event handling is wired end-to-end between NATS intake, coordinator correlation, and stem-cell reception

### Implementation rules

- Make the smallest coherent set of code changes that fully completes the STDP backend upgrade.
- Prefer preserving bounded public APIs where reasonable, but rewrite semantics aggressively where they are still string-severity or non-STDP-centric.
- Do not leave dead schema branches, dead tests, or partially migrated consumer logic behind.
- Keep comments concise and only where they clarify non-obvious trace decay, monotonic timing, or typed event routing behavior.
- Maintain the biological framing: operator nociception, eligibility traces, STDP pruning, and bounded metabolic response.

### Deliverables

Return:

1. The code changes.
2. A short summary of what was added, rewritten, and migrated.
3. The verification steps you ran.
4. Any residual risks if later phases such as Rhizome pruning detail, dashboard operator wiring, or higher-order consolidation are still pending outside `app/nervous_system` and `app/core`.
