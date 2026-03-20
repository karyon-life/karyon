# Sleep/Dream Language Consolidation Prompt

Use this prompt to direct an implementation model to perform the Phase 6 sleep/dream refactor described in [`chat2.xml`](/home/adrian/Projects/nexical/karyon/chat2.xml): reconfigure Karyon’s sleep cycle to invent grammar from Operator Sandbox byte sequences, reconfigure dream-state to simulate grammar internally rather than replay execution, and strictly close the waking-world membrane during Digital Torpor.

## Prompt

You are refactoring the Karyon repository at `/home/adrian/Projects/nexical/karyon`.

Your objective is to execute the Phase 6 "Consolidation & Dreaming" pivot described in `chat2.xml`: turn sleep into a language-first grammar consolidation cycle over Operator Sandbox `PooledSequence` traffic, turn dreaming into bounded internal Monte Carlo grammar simulation, and hard-close the external Operator Sandbox membrane whenever `Core.MetabolicDaemon` forces Digital Torpor.

### Architectural intent

- Treat `chat2.xml` as the architectural source of truth for this refactor, especially:
  - the waking / sleeping / dreaming separation
  - the requirement that sleep invent grammar from `PooledSequence` nodes
  - the requirement that dreaming is internal dialog, not external action
  - the requirement that the membrane closes during Digital Torpor
- This is not a generic graph optimization pass. It is the distributed systems implementation of sleep-time grammar abstraction and dream-time free-energy simulation.
- Preserve the Karyon constraints in `AGENTS.md` and `GEMINI.md`: biology first, actor isolation, no centralized mutable state, no monolithic orchestration, no direct UI writes to Rhizome, and no weakening of OTP fault tolerance or metabolic governance.

### Important repo facts you must honor

- [`app/rhizome/lib/rhizome/consolidation_manager.ex`](/home/adrian/Projects/nexical/karyon/app/rhizome/lib/rhizome/consolidation_manager.ex) currently:
  - classifies all graph nodes generically
  - creates `SleepSuperNode` abstractions
  - calls the generic `Rhizome.Native.optimize_graph/0`
- [`app/rhizome/native/rhizome_nif/src/optimizer.rs`](/home/adrian/Projects/nexical/karyon/app/rhizome/native/rhizome_nif/src/optimizer.rs) currently uses **Leiden**, not Louvain, and clusters the whole graph rather than an Operator Sandbox `PooledSequence` subgraph.
- [`app/rhizome/lib/rhizome/memory.ex`](/home/adrian/Projects/nexical/karyon/app/rhizome/lib/rhizome/memory.ex) currently persists `PooledSequence` nodes with:
  - `signature`
  - `raw_bytes`
  - `encoding`
  - `occurrences`
  - `activation_threshold`
  - `window_size`
  - `observed_at`
  but it does **not** currently persist Operator Sandbox provenance or sensory-organ source metadata.
- [`app/core/lib/core/simulation_daemon.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/simulation_daemon.ex) currently:
  - queries recent execution outcomes
  - builds execution-style permutation plans
  - still routes dreaming through an executor boundary
- [`app/core/lib/core/metabolic_daemon.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/metabolic_daemon.ex) currently:
  - emits pressure telemetry and `metabolic.spike` messages
  - logs Digital Torpor when IOPS are high
  - does **not** publish an explicit `consciousness_state` / `membrane_open` contract
- [`app/operator_environment/lib/operator_environment_web/live/operator_sandbox_live/index.ex`](/home/adrian/Projects/nexical/karyon/app/operator_environment/lib/operator_environment_web/live/operator_sandbox_live/index.ex) currently always accepts operator input and has no torpor or dream-state lockout.
- [`app/nervous_system/lib/nervous_system/pub_sub.ex`](/home/adrian/Projects/nexical/karyon/app/nervous_system/lib/nervous_system/pub_sub.ex) is now the direct waking-world bus facade. Use it as the membrane transport surface instead of inventing a new control-plane boundary.

### Non-negotiable runtime constraints

- Keep `Rhizome.ConsolidationManager` as the public sleep-cycle orchestrator.
- Keep `Core.SimulationDaemon` as the public dream-cycle orchestrator.
- Keep `Core.MetabolicDaemon` as the authority for Digital Torpor.
- Keep `NervousSystem.PubSub` as the membrane transport surface.
- Do not reopen the external membrane during torpor or dreaming.
- Do not allow the Operator Sandbox LiveView to bypass the membrane through direct calls into Rhizome or other storage layers.
- Do not introduce centralized global mutable state or an out-of-band membrane controller when the existing `MetabolicDaemon` + `NervousSystem.PubSub` path can carry the state explicitly.

### Required pooled-sequence provenance change

Before targeted grammar consolidation can work, extend the pooled-sequence persistence contract.

Requirements:

1. Update `Rhizome.Memory.persist_pooled_sequence/1` so it accepts and persists explicit provenance metadata for language-learning traffic.
2. At minimum, persist fields equivalent in meaning to:
   - `source: "operator_environment"`
   - `organ: "tabula_rasa_ingestor"` or equivalent sensory-organ marker
3. Update the Operator Sandbox / tabula-rasa ingestion path so `PooledSequence` nodes created from live operator interaction actually populate those fields.
4. Do not infer Operator Sandbox origin indirectly from timestamps or window size. Persist it explicitly.

### Sleep-cycle refactor

Refactor `Rhizome.ConsolidationManager` so sleep consolidates language, not generic graph debris.

#### Consolidation scope

- sweep only `PooledSequence` nodes whose provenance marks them as Operator Sandbox-originated
- target their co-occurrence graph, not the entire working graph
- keep the public `run_once/1` contract intact where reasonable, but rewrite its internal semantics toward grammar consolidation

#### Community detection

- replace the current Leiden optimizer path with **Louvain** community detection
- apply it only to the induced subgraph of Operator Sandbox `PooledSequence` nodes and their co-occurrence relationships
- keep the heavy clustering work in Rust
- keep orchestration, clocking, and archive bridging in Elixir

#### Required graph query contract

Use the co-occurrence graph as the clustering source. The intent must be equivalent to:

```cypher
MATCH (a:PooledSequence)-[r:CO_OCCURS_WITH]->(b:PooledSequence)
WHERE a.source = 'operator_environment'
  AND b.source = 'operator_environment'
RETURN id(a) AS start, id(b) AS end, coalesce(r.weight, 1.0) AS weight
```

Do not cluster generic `Cell`, `PredictionError`, or unrelated graph nodes in this grammar path.

#### Grammar super-node model

Replace generic `SleepSuperNode` semantics with grammar-specific abstractions.

Requirements:

- use `GrammarSuperNode` as the abstraction label
- set `kind: "structural_grammar_rule"`
- create a super-node only for communities with more than one member
- connect the grammar node to its member pooled sequences via `ABSTRACTS` edges
- persist metadata at minimum equivalent to:
  - `community_size`
  - `confidence`
  - `created_at`
  - `observed_at`
  - `source: "operator_environment"`

The collapse logic must be equivalent in meaning to:

```cypher
MERGE (g:GrammarSuperNode {id: $grammar_id})
SET g.kind = 'structural_grammar_rule',
    g.community_size = $community_size,
    g.confidence = $confidence,
    g.source = 'operator_environment',
    g.created_at = $created_at,
    g.observed_at = $observed_at
WITH g
MATCH (p:PooledSequence)
WHERE id(p) IN $member_ids
MERGE (g)-[r:ABSTRACTS]->(p)
SET r.kind = 'grammar_consolidation',
    r.created_at = $created_at
```

#### Observability and compatibility

- update downstream observability, tests, and reporting surfaces that still assume `SleepSuperNode`
- preserve the general idea of sleep-cycle abstraction counts, but make them grammar-specific

### Dream-state refactor

Refactor `Core.SimulationDaemon` so dreaming is internal grammar simulation, not execution replay.

Requirements:

1. Stop using the executor membrane for dreaming.
   - do not call `execute_plan/1`
   - do not emit externally actionable motor work from dream-state
2. Replace recent execution-outcome replay with bounded retrieval of:
   - recent `GrammarSuperNode`s
   - their related `PooledSequence` members
3. Run bounded Monte Carlo traversals entirely in simulation.
   - combine grammar super-nodes into hypothetical linguistic trajectories
   - compute predicted Free Energy from simulated paths only
   - do not use external operator feedback, external sockets, or waking-world side effects during traversal
4. Persist the resulting dream artifact through Rhizome as an internal simulation event.

#### Dream-state persistence contract

Extend the SimulationDaemon event shape so it includes fields equivalent in meaning to:

- `dream_mode: "grammar_monte_carlo"`
- `predicted_free_energy`
- `external_motor_output_used: false`
- the grammar super-node ids and/or sequence lineage used in the traversal

Do not keep execution-era `vm_id` / executor assumptions as the primary dream-state identity surface.

#### Motor-output severance

While `SimulationDaemon` is actively dreaming:

- sever external motor-output delivery
- do not publish motor babble to the Operator Sandbox
- do not use the waking-world output membrane
- keep any simulated output internal to telemetry and Rhizome documents only

### Membrane state contract

Make membrane closure explicit and typed.

#### MetabolicDaemon authority

`Core.MetabolicDaemon` remains the authority for Digital Torpor and must publish explicit membrane-state telemetry.

At minimum, add telemetry fields equivalent in meaning to:

- `consciousness_state`
- `membrane_open`
- `motor_output_open`

Default states must be:

- `:awake`
- `:torpor`
- `:dreaming`

And the default closure rules must be:

- `:awake` => `membrane_open: true`, `motor_output_open: true`
- `:torpor` => `membrane_open: false`, `motor_output_open: false`
- `:dreaming` => `membrane_open: false`, `motor_output_open: false`

#### Bus-level enforcement

Use `NervousSystem.PubSub` as the membrane-state transport and enforcement surface.

Requirements:

- gate `:sensory_input` and `:motor_output` traffic through membrane state
- when the membrane is closed, input bytes must be dropped rather than buffered for later replay
- do not invent a separate membrane bus if `NervousSystem.PubSub` can carry the needed state

#### Operator Sandbox lockout

Update `OperatorEnvironmentWeb.OperatorSandboxLive.Index` so the waking-world membrane visibly and actually closes.

Requirements:

- subscribe to typed membrane-state telemetry
- render the operator controls as disabled when `membrane_open` is false
- reject `stream_bytes`, `bundle_input`, and biological feedback events server-side when the membrane is closed
- do not rely on client-side disabling alone

If the operator types during torpor, the bytes must bounce off the membrane and disappear; they must not queue for delayed ingestion.

### Optimizer migration requirements

Refactor the Rust optimizer specifically.

Requirements:

- replace Leiden with Louvain in [`app/rhizome/native/rhizome_nif/src/optimizer.rs`](/home/adrian/Projects/nexical/karyon/app/rhizome/native/rhizome_nif/src/optimizer.rs)
- restrict the optimizer query to Operator Sandbox `PooledSequence` communities
- generate `GrammarSuperNode` abstractions instead of generic `SuperNode` / `SleepSuperNode` semantics for this path
- preserve dirty-scheduler execution for the heavy graph work

Do not leave the old generic whole-graph Leiden path as the active sleep-cycle implementation.

### Explicit prohibitions

The implementation must forbid:

- clustering the entire graph during grammar consolidation
- leaving `SleepSuperNode` as the active label for this language-consolidation path
- calling `execute_plan/1` from `SimulationDaemon` during dreaming
- sending external motor babble while dreaming
- allowing Operator Sandbox input through during Digital Torpor
- client-only torpor lockout with no server-side event rejection

If the implementation still allows `stream_bytes` to pass through while `MetabolicDaemon` reports torpor, it is incorrect.

### Test and verification requirements

Update the Rhizome, core, and operator-environment tests to match the new sleep/dream architecture.

At minimum:

1. Rewrite Rhizome consolidation tests to verify:
   - only Operator Sandbox `PooledSequence` nodes are clustered
   - Louvain is the active clustering algorithm
   - multi-member communities collapse into `GrammarSuperNode`s
   - generic non-language nodes are excluded from this grammar path
2. Rewrite dream-state tests to verify:
   - `SimulationDaemon` no longer calls an executor during dreaming
   - Monte Carlo traversal uses grammar super-nodes and computes predicted Free Energy
   - external motor-output delivery is severed while dreaming
3. Rewrite metabolic and operator-environment tests to verify:
   - `MetabolicDaemon` publishes `consciousness_state`, `membrane_open`, and `motor_output_open`
   - the LiveView visually locks during torpor
   - the LiveView rejects input server-side during torpor
   - input bytes are dropped, not buffered, while the membrane is closed
4. Run a repo search and confirm:
   - the active sleep path no longer creates generic `SleepSuperNode`s for this language-consolidation flow
   - the active dream path no longer routes through `execute_plan/1`
   - Operator Sandbox input is gated by torpor state rather than always-on `stream_bytes`

### Implementation rules

- Make the smallest coherent set of code changes that fully completes the sleep/dream language pivot.
- Prefer preserving public daemon entrypoints where reasonable (`run_once/1`, supervision ownership), but rewrite the internal semantics aggressively where they are still execution-centric or whole-graph generic.
- Keep the biological framing explicit: waking membrane, Digital Torpor, sleep consolidation, grammar abstraction, dream-state simulation, and Free Energy minimization.
- Keep comments concise and only where they clarify non-obvious membrane closure, clustering scope, or dream-state simulation behavior.

### Deliverables

Return:

1. The code changes.
2. A short summary of what was rewritten in sleep, dream, and membrane-state handling.
3. The verification steps you ran.
4. Any residual risks if later semantic grounding or dashboard observability flows still need to consume the new grammar super-node and torpor-state contracts.
