# Rhizome Structural Plasticity Prompt

Use this prompt to direct an implementation model to perform the database-layer structural plasticity refactor described in [`chat2.xml`](/home/adrian/Projects/nexical/karyon/chat2.xml): upgrade `app/rhizome` so STDP nociception triggers variable-severity Memgraph mutations and every successful mutation is dual-written as an immutable trauma event into XTDB.

## Prompt

You are refactoring the Karyon repository at `/home/adrian/Projects/nexical/karyon`.

Your objective is to execute the structural plasticity upgrade described in `chat2.xml`: take the already-typed `{:stdp_prediction_error, sensory_id, severity}` signal from `Core.StemCell`, route it into a dedicated Rhizome plasticity API, apply severity-dependent Memgraph mutations, and record every successful nociception-triggered mutation in the XTDB archival ledger as immutable trauma history.

### Architectural intent

- Treat `chat2.xml` as the architectural source of truth for this refactor, especially the structural plasticity section describing STDP pruning, Memgraph edge mutation, and bitemporal trauma retention.
- This is not a generic graph helper cleanup. It is the database-layer implementation of biological structural plasticity.
- Preserve the Karyon constraints in `AGENTS.md` and `GEMINI.md`: biology first, no centralized mutable state, no monolithic control plane, and no weakening of OTP fault tolerance or metabolic governance.

### Important repo facts you must honor

- [`app/core/lib/core/stem_cell.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/stem_cell.ex) already traps `{:stdp_prediction_error, sensory_id, severity}` but currently dispatches directly to `rhizome_module().prune_pathway/1`.
- [`app/rhizome/lib/rhizome/native.ex`](/home/adrian/Projects/nexical/karyon/app/rhizome/lib/rhizome/native.ex) currently exposes `reinforce_pathway/1` and `prune_pathway/1`.
- `Rhizome.Native.prune_pathway/1` currently weakens an edge by lowering `r.weight`; it does not implement true severity-dependent LTD vs deletion behavior.
- [`app/rhizome/lib/rhizome/memory.ex`](/home/adrian/Projects/nexical/karyon/app/rhizome/lib/rhizome/memory.ex) already owns the typed Memgraph and XTDB boundaries and already archives typed prediction errors, but it has no STDP-specific structural plasticity API and no trauma-event archive contract.
- [`app/rhizome/lib/rhizome/memory_topology.ex`](/home/adrian/Projects/nexical/karyon/app/rhizome/lib/rhizome/memory_topology.ex) currently has no `:prune_stdp_pathway` or `:submit_trauma_event` operations.
- The current Memgraph execution model in this repo is `Rhizome.Memory` -> `Rhizome.Native.memgraph_query/1` with query strings. Do not invent `Memgraph.execute/2`.

### Non-negotiable runtime constraints

- Keep `Core.StemCell` as the caller of a typed `Rhizome.Memory` API, not raw Memgraph calls and not raw `Rhizome.Native` calls.
- Keep all Cypher execution behind `Rhizome.Memory` and `Rhizome.Native`.
- Keep every successful nociception-triggered mutation dual-written into XTDB as immutable trauma history.
- Do not bypass the typed memory layer with opaque graph mutations from `Core.StemCell`.
- Do not weaken existing Rhizome topology boundaries or collapse Memgraph and XTDB concerns into one untyped helper.

### Required core integration change

Update `Core.StemCell` so the STDP handler no longer dispatches to the generic raw pruning path.

Requirements:

- replace direct STDP dispatch to `rhizome_module().prune_pathway/1`
- call `Rhizome.Memory.prune_stdp_pathway/1` instead
- pass a bounded typed map containing at least:
  - `sensory_id`
  - `motor_id`
  - `severity`
  - `trace_id`
  - timestamps or equivalent event-time evidence
- keep trauma archival inside `Rhizome.Memory`, not in `Core.StemCell`

### Required Rhizome APIs

Add a dedicated structural plasticity API in `Rhizome.Memory`.

#### Required new entrypoints

1. `Rhizome.Memory.prune_stdp_pathway/1`
2. `Rhizome.Memory.submit_trauma_event/1`

#### Required topology additions

Update `Rhizome.MemoryTopology` to include:

- `:prune_stdp_pathway` on the `:working_graph` layer
- `:submit_trauma_event` on the `:temporal_archive` layer

Do not overload the existing generic `prune_pathway/1` contract with STDP-specific branching. Add the new typed API explicitly.

### STDP plasticity contract

Implement `Rhizome.Memory.prune_stdp_pathway/1` as a typed structural plasticity boundary.

Requirements:

- validate payload shape before any graph mutation
- branch on a severity threshold of `0.5`
- execute the Memgraph mutation
- dual-write the trauma archive record on every successful mutation
- return a typed result that indicates whether the pathway was:
  - `:depressed`
  - `:deleted`
  - or a bounded no-op if the edge was already absent

The target edge shape is:

- `(s:PooledSequence {id: $sensory_id})-[r:PREDICTS_SUCCESS]->(m:MotorAction {id: $motor_id})`

### Variable-severity Memgraph mutations

Implement two explicit mutation paths for the same STDP target edge.

#### Low-severity pain: LTD

For low-severity nociception where `severity < 0.5`, implement Long-Term Depression by degrading the `weight` property on the target edge.

Requirements:

- preserve the edge
- lower `r.weight` by a severity-derived delta
- never allow the result to fall below `0.0`
- mark the edge as structurally depressed rather than deleted

Use a deterministic Cypher query in the current Rhizome execution model. The intent must be equivalent to:

```cypher
MATCH (s:PooledSequence {id: '<sensory_id>'})-[r:PREDICTS_SUCCESS]->(m:MotorAction {id: '<motor_id>'})
SET r.weight = CASE
  WHEN coalesce(r.weight, 1.0) - <delta> < 0.0 THEN 0.0
  ELSE coalesce(r.weight, 1.0) - <delta>
END,
    r.status = 'depressed',
    r.trace_id = '<trace_id>',
    r.last_pruned_at = <event_at>
RETURN r.weight AS weight
```

#### High-severity pain: Apoptosis

For high-severity nociception where `severity >= 0.5`, implement structural apoptosis by deleting the target edge outright.

Requirements:

- delete the edge instead of weakening it
- treat a missing edge as an idempotent no-op rather than a hard failure
- preserve typed result handling so callers can distinguish deletion from absence

Use a deterministic Cypher query in the current Rhizome execution model. The intent must be equivalent to:

```cypher
MATCH (s:PooledSequence {id: '<sensory_id>'})-[r:PREDICTS_SUCCESS]->(m:MotorAction {id: '<motor_id>'})
WITH r, count(r) AS matched
FOREACH (_ IN CASE WHEN matched > 0 THEN [1] ELSE [] END | DELETE r)
RETURN matched AS pruned_edges
```

Do not implement the high-severity path as another weight reduction.

### Trauma archive requirements

Every successful nociception-triggered graph mutation must be dual-written as an immutable trauma event into XTDB.

Add `Rhizome.Memory.submit_trauma_event/1` and require `Rhizome.Memory.prune_stdp_pathway/1` to call it internally for both:

- LTD / depression
- apoptosis / deletion

The trauma event must be a typed XTDB document, not an ad hoc map write from `Core.StemCell`.

#### Required trauma shape

Persist a document equivalent in meaning to:

- unique id such as `trauma_event:<trace_id>:<timestamp>`
- schema or document type such as `karyon.trauma-event.v1`
- `sensory_id`
- `motor_id`
- `severity`
- `plasticity_mode`
- `edge_action`
- `trace_id`
- `recorded_at`
- `observed_at`

Ensure the archive event is immutable and queryable through XTDB history surfaces.

Do not reuse `submit_prediction_error/1` as the sole archive mechanism for structural plasticity history. This refactor requires an explicit trauma-event archive contract.

### Rhizome execution model requirements

Use the current repo execution model:

- `Rhizome.Memory` owns typed orchestration and validation
- `Rhizome.Native` owns query construction / execution
- `Rhizome.Native.memgraph_query/1` remains the underlying Memgraph execution primitive unless you add a typed parameter-spec helper there

You may continue using escaped query-string construction in `Rhizome.Native`, or add a typed helper that still compiles to the existing execution primitive. Do not invent a separate Memgraph client API.

### Explicit prohibitions

The implementation must forbid:

- raw Memgraph query strings emitted directly from `Core.StemCell`
- trauma archival written directly from core modules
- overloading `prune_pathway/1` with ambiguous STDP behavior instead of adding a new typed STDP API
- high-severity STDP implemented as another weight decrement
- opaque archive blobs instead of typed XTDB documents

If the implementation still routes STDP through the generic `prune_pathway/1` contract from `Core.StemCell`, it is incorrect.

### Test and verification requirements

Update the Rhizome and core tests so they match the new structural plasticity behavior.

At minimum:

1. Rewrite core tests to verify:
   - `Core.StemCell` dispatches STDP events to `Rhizome.Memory.prune_stdp_pathway/1`
   - low severity produces LTD semantics
   - high severity produces deletion semantics
2. Rewrite Rhizome memory tests to verify:
   - `Rhizome.Memory.prune_stdp_pathway/1` rejects invalid payloads
   - `Rhizome.Memory.submit_trauma_event/1` rejects invalid trauma shapes
   - `Rhizome.MemoryTopology` includes both new operations
   - every successful mutation dual-writes a trauma event to XTDB
3. Rewrite Rhizome native tests to verify:
   - the LTD Cypher builder emits a weight-degrading query
   - the apoptosis Cypher builder emits a deletion query
   - no opaque Memgraph execution leaks back into `Core.StemCell`
4. Run a repo search and confirm:
   - STDP no longer routes through the generic `prune_pathway/1` path from `Core.StemCell`
   - trauma archival is handled through typed Rhizome APIs rather than ad hoc XTDB writes from core

### Implementation rules

- Make the smallest coherent set of code changes that fully completes the structural plasticity upgrade.
- Prefer preserving existing Rhizome topology patterns and typed memory boundaries, but rewrite the STDP mutation semantics aggressively where they are still generic or ambiguous.
- Do not leave partially migrated STDP paths behind.
- Keep comments concise and only where they clarify the LTD vs apoptosis distinction or the dual-write trauma behavior.
- Maintain the biological framing: nociception, LTD, apoptosis, structural plasticity, and durable trauma memory.

### Deliverables

Return:

1. The code changes.
2. A short summary of what was added, rewritten, and dual-written.
3. The verification steps you ran.
4. Any residual risks if broader Rhizome consolidation or dashboard/operator feedback flows still need to consume the new trauma-event history.
