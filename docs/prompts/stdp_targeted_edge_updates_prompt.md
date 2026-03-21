# STDP Targeted Edge Updates Prompt

Use this prompt to direct an implementation model to perform the STDP coordination rewrite described in [`chat3.xml`](/home/adrian/Projects/nexical/karyon/chat3.xml): remove the current global-broadcast nociception behavior from `Sensory.STDPCoordinator` and replace it with localized, actor-safe edge correction events that weaken only the failed prediction edge and strengthen only the corrected edge.

## Prompt

You are refactoring the Karyon repository at `/home/adrian/Projects/nexical/karyon`.

Act as a distributed systems engineer specializing in Elixir GenServers and Actor-model state mutations.

Your objective is to execute the STDP refactor described in `chat3.xml`: remove the global broadcast pain response tied to an eligibility time-window from `app/nervous_system/lib/sensory/stdp_coordinator.ex`, replace it with **Targeted Edge Updates**, extend the `PredictionError` protobuf so it carries explicit graph-correction targets, and update the coupled core/nervous-system tests so the learning path becomes edge-specific instead of sentence-global.

## Architectural intent

- Treat `chat3.xml` as the architectural source of truth for this refactor, especially the sections arguing that the current STDP path is wrong for language because it punishes every recent trace inside a time window instead of isolating the specific failed edge.
- This is not a transport-only cleanup. It is the actor-model implementation of localized neuroplasticity in response to explicit operator correction.
- Preserve the Karyon constraints in `AGENTS.md` and `GEMINI.md`: biology first, actor isolation, no centralized mutable state, no global locks, no monolithic coordinator, and no bypassing the typed Rhizome/Core boundaries.

## Important repo facts you must honor

- [`app/nervous_system/lib/sensory/stdp_coordinator.ex`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/sensory/stdp_coordinator.ex) already exists, is already supervised by [`NervousSystem.Application`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/nervous_system/application.ex), and currently stores traces in GenServer-local state.
- The current coordinator is wrong because `route_operator_nociception/2` iterates every trace in the eligibility window and sends the same `{:stdp_prediction_error, sensory_id, severity}` message to every stem cell.
- [`app/nervous_system/priv/proto/prediction_error.proto`](/home/adrian/Projects/nexical/karyon/app/nervous_system/priv/proto/prediction_error.proto) currently does **not** contain the required graph-correction fields `source_node`, `predicted_target`, and `corrected_target`.
- [`app/core/lib/core/stem_cell.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/stem_cell.ex) currently handles `{:stdp_prediction_error, sensory_id, severity}` by pruning a single STDP pathway through `Rhizome.Memory.prune_stdp_pathway/1`. That tuple shape is insufficient for targeted correction because it cannot express both the failed target and the corrected target.
- [`app/core/lib/core/metabolic_daemon.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/metabolic_daemon.ex) currently exposes pressure/runtime state but does **not** expose a typed node-lock API for STDP mutation coordination. If node-lock awareness is required, you must add the smallest explicit typed coordination surface rather than inventing hidden lock state.
- [`app/nervous_system/test/nervous_system/stdp_coordinator_test.exs`](/home/adrian/Projects/nexical/karyon/app/nervous_system/test/nervous_system/stdp_coordinator_test.exs) currently encodes the old broadcast behavior as correct and must be rewritten.

## Non-negotiable runtime constraints

- Keep `Sensory.STDPCoordinator` as a GenServer with local state only.
- Preserve `:one_for_one` supervision in `NervousSystem.Application`.
- Do not introduce ETS, process-external mutable buffers, mutexes, or global registries to solve edge targeting.
- Keep operator nociception intake on the existing control-plane boundary. Do not bypass `NervousSystem.Endocrine` or the existing message transport path.
- Do not keep any active global broadcast fallback once the targeted update path is implemented.
- Do not block inside the coordinator while waiting on long-running graph mutations or retry loops.

## Required protobuf rewrite

Update [`app/nervous_system/priv/proto/prediction_error.proto`](/home/adrian/Projects/nexical/karyon/app/nervous_system/priv/proto/prediction_error.proto).

### Required fields

When a `PredictionError` protobuf is received for STDP correction, it must contain all three of the following fields:

- `source_node`
- `predicted_target`
- `corrected_target`

These fields are required because the correction is no longer a generic pain signal; it is an explicit edge mutation instruction.

### Additional requirements

- Keep existing fields only if they are still needed by active consumers.
- Do not hide the three required targeting fields inside `metadata`.
- Update generated Protox consumers and tests accordingly.
- Keep decode behavior explicit and typed.

If the resulting protobuf still requires callers to recover these fields indirectly from free-form metadata, the refactor is incorrect.

## Required STDP coordinator rewrite

Completely refactor [`app/nervous_system/lib/sensory/stdp_coordinator.ex`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/sensory/stdp_coordinator.ex).

### Mandatory deletions

You must remove all active logic that:

- broadcasts pain to every trace in the time window
- iterates all traces on a nociception event and sends the same failure to every stem cell
- treats the eligibility window itself as the targeting mechanism

If `route_operator_nociception/2` still sends the same nociception event to every active trace, the refactor is incorrect.

### Required replacement behavior

Implement **Targeted Edge Updates**.

When a `PredictionError` protobuf is received:

1. Decode it through the updated protobuf contract.
2. Validate that `source_node`, `predicted_target`, and `corrected_target` are present and non-empty.
3. Use those fields to locate the exact correlated trace or active action lineage, rather than walking every trace in the eligibility window.
4. Emit a localized negative update to weaken the edge between `source_node` and `predicted_target`.
5. Emit a localized positive update to strengthen the edge between `source_node` and `corrected_target`.

The coordinator must no longer say “some recent action was bad.” It must say “this exact predicted edge was wrong, and this exact corrected edge should be reinforced.”

### Required message semantics

The resulting Elixir path must send:

- a localized negative metabolic spike to weaken `source_node -> predicted_target`
- a localized positive metabolic spike to strengthen `source_node -> corrected_target`

You may encode this as two explicit typed messages, or one typed correction message that contains both mutations, but the behavior must be decision-complete and edge-specific.

Do not keep the current tuple-only `{:stdp_prediction_error, sensory_id, severity}` path as the primary runtime behavior for this feature.

## Required race-condition handling

You must explicitly handle asynchronous race conditions if the target nodes are currently locked by `Core.MetabolicDaemon`.

### Required coordination rule

The implementation must not assume the target nodes are always immediately mutable.

If `source_node`, `predicted_target`, or `corrected_target` are currently locked or unavailable because of MetabolicDaemon-managed pressure or mutation coordination:

- do not drop the correction silently
- do not block the coordinator indefinitely
- do not mutate shared global state to “reserve” nodes

### Required implementation expectation

If no explicit lock-status API currently exists, add the **smallest typed coordination surface** needed so the coordinator can:

- detect that a target node is currently locked or mutation-blocked
- defer, retry, or requeue the targeted update in a bounded, actor-safe way
- preserve message ordering guarantees within the owning GenServer as much as possible

Use bounded retry/defer behavior with explicit state transitions. Do not add background busy-wait loops or ad hoc sleeps in random processes.

## Required Core integration

Update the coupled core handling so the targeted STDP correction path remains coherent.

Requirements:

- inspect and update [`app/core/lib/core/stem_cell.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/stem_cell.ex) so it can receive and process targeted correction semantics rather than the old single-edge prune tuple
- preserve the existing biological meaning: failed edge gets weakened, corrected edge gets reinforced
- do not collapse both updates into a generic prune-only path
- keep the actual edge mutation routed through the typed Rhizome/Core memory boundary rather than raw graph calls from the coordinator

If the corrected target is never positively reinforced, the refactor is incomplete.

## Test and verification requirements

Rewrite the tests that currently encode the wrong behavior.

### Nervous-system tests

Rewrite [`app/nervous_system/test/nervous_system/stdp_coordinator_test.exs`](/home/adrian/Projects/nexical/karyon/app/nervous_system/test/nervous_system/stdp_coordinator_test.exs) so it verifies:

- the coordinator no longer broadcasts one pain event to every active trace
- a `PredictionError` with `source_node`, `predicted_target`, and `corrected_target` yields targeted edge updates only for the matching trace
- the coordinator emits both negative and positive updates for the two distinct edges
- expired traces are still pruned and do not receive corrections
- locked-node scenarios are handled through bounded defer/retry behavior rather than dropped or globally rebroadcast messages

### Protobuf tests

Rewrite protobuf tests so they verify:

- `PredictionError` round-trips with `source_node`, `predicted_target`, and `corrected_target`
- missing targeting fields are rejected or dropped according to explicit policy
- consumers no longer depend on opaque metadata for edge targeting

### Core tests

Rewrite or extend core tests so they verify:

- `Core.StemCell` no longer treats STDP correction as prune-only
- the failed edge receives a weakening update
- the corrected edge receives a strengthening update
- race conditions against `MetabolicDaemon` lock state are handled deterministically

### Repo-wide verification

Run a repo search and confirm:

- no active STDP path still performs a global pain broadcast over the full eligibility window
- no active STDP path still depends on `PredictionError.metadata` for `source_node`, `predicted_target`, or `corrected_target`

## Explicit prohibitions

The implementation must forbid:

- global broadcast pain tied to the time window
- sentence-level or window-wide punishment when only one edge failed
- hidden targeting fields in untyped metadata
- indefinite blocking on node locks
- global lock registries or ETS lock tables for this feature
- direct raw graph mutation from the coordinator

If the resulting system still punishes all recent traces when one prediction is corrected, it is incorrect.

## Implementation rules

- Make the smallest coherent set of changes that fully migrates STDP from global nociception broadcast to targeted edge correction.
- Preserve public supervision and actor boundaries where reasonable, but rewrite the STDP message semantics aggressively.
- Keep comments concise and only where they clarify targeted correction routing or lock-aware retry behavior.
- Maintain the biological framing: localized nociception, targeted edge weakening, corrective reinforcement, and bounded metabolic coordination.

## Deliverables

Return:

1. The code changes.
2. A short summary of what global-broadcast behavior was removed and what targeted edge update path replaced it.
3. The verification steps you ran.
4. Any residual risks if later phases such as Rhizome persistence detail or operator-environment correction UX still assume the old broadcast model.
