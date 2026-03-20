# Tabula Rasa Sensory Ingestion Pivot Prompt

Use this prompt to direct an implementation model to perform the Phase 2 sensory refactor described in [`chat2.xml`](/home/adrian/Projects/nexical/karyon/chat2.xml): destroy the AST-oriented sensory perimeter and replace it with a language-first, tabula rasa ingestion pipeline centered on continuous raw-byte intake, sliding-window spatial pooling, and direct `PooledSequence` projection into Memgraph.

## Prompt

You are refactoring the Karyon repository at `/home/adrian/Projects/nexical/karyon`.

Your objective is to execute the Phase 2 "Sensory Ingestion Pivot" described in `chat2.xml`: remove deterministic code-parser assumptions from `app/sensory` and replace them with a language-first, tabula rasa ingestion boundary that listens to raw bytes, pools repeated sequences, and projects those sequences into the Rhizome as explicit `PooledSequence` nodes.

### Architectural intent

- Treat `chat2.xml` as the architectural source of truth for this refactor, especially:
  - "Eradicate the Eyes and Rely on the Skin"
  - "Tabula Rasa Ingestion Pipeline"
  - Phase 2 "The Sensory Ingestion Pivot"
- This is not an NLP integration. The organism must not receive parser shortcuts, tokenizers, ASTs, or pre-trained priors.
- Preserve the Karyon constraints in `AGENTS.md` and `GEMINI.md`: biology first, actor isolation, no centralized mutable state, no monolithic orchestration, and no weakening of OTP supervision or metabolic governance.

### Important repo facts you must honor

- [`app/sensory/lib/sensory/eyes.ex`](/home/adrian/Projects/nexical/karyon/app/sensory/lib/sensory/eyes.ex) is currently the repository/AST entrypoint.
- [`app/sensory/lib/sensory.ex`](/home/adrian/Projects/nexical/karyon/app/sensory/lib/sensory.ex) still publicly delegates `parse_repository/2` and `project_repository/2` to `Sensory.Eyes`.
- [`app/sensory/lib/sensory/native.ex`](/home/adrian/Projects/nexical/karyon/app/sensory/lib/sensory/native.ex), [`app/sensory/lib/sensory/raw.ex`](/home/adrian/Projects/nexical/karyon/app/sensory/lib/sensory/raw.ex), and [`app/sensory/native/sensory_nif/src/lib.rs`](/home/adrian/Projects/nexical/karyon/app/sensory/native/sensory_nif/src/lib.rs) are still Tree-sitter and AST driven.
- [`app/sensory/lib/sensory/application.ex`](/home/adrian/Projects/nexical/karyon/app/sensory/lib/sensory/application.ex) currently supervises only `Sensory.StreamSupervisor` under `:one_for_one`.
- [`app/rhizome/lib/rhizome/memory.ex`](/home/adrian/Projects/nexical/karyon/app/rhizome/lib/rhizome/memory.ex) currently exposes `persist_pooled_pattern/1`, which writes `PooledPattern` pair abstractions. That does not satisfy the requested `PooledSequence` node model, so this refactor must add a new sequence-specific `Rhizome.Memory` API rather than overloading the existing pooled-pattern contract.

### Non-negotiable runtime constraints

- Preserve OTP `:one_for_one` supervision in the sensory application.
- Keep the ingestion path actor-oriented and non-blocking. Use GenServer boundaries rather than global buffers or shared mutable state.
- Do not introduce external NLP APIs, pre-trained tokenizers, dependency parsers, or hidden parser shortcuts.
- Do not bypass `Rhizome.Memory` with opaque Cypher strings from the sensory layer.
- Do not expand scope into the operator environment or sandbox replacement; mention grounding context only as background, not implementation scope.

### Required code changes

1. Delete `Sensory.Eyes` and remove all public delegates, references, perimeter policy entries, tests, and assumptions tied to deterministic repository parsing.
2. Remove Rust Tree-sitter dependencies and AST-specific sensory NIF functions, including:
   - Tree-sitter crates and imports in the sensory Rust crate
   - `parse_code/2`
   - `parse_to_graph/2`
   - AST-ingestion flows exposed through `Sensory.Native` and `Sensory.Raw`
3. Delete or rewrite AST-oriented sensory tests and NIF contract checks, including any tests centered on:
   - `Sensory.Eyes`
   - deterministic AST accuracy
   - `parse_to_graph`
   - direct AST ingestion into Memgraph
   - parser scheduler assertions
4. Inspect dependent sensory modules and rewrite them so the sensory perimeter compiles and remains coherent after the AST path is removed. At minimum, evaluate and update:
   - `app/sensory/lib/sensory/application.ex`
   - `app/sensory/lib/sensory.ex`
   - `app/sensory/lib/sensory/perimeter.ex`
   - `app/sensory/lib/sensory/stream_supervisor.ex`
   - `app/sensory/lib/sensory/skin.ex`
   - `app/sensory/lib/sensory/spatial_pooler.ex`
   - `app/rhizome/lib/rhizome/memory.ex`

### New sensory architecture

Architect a new `Sensory.TabulaRasa.Ingestor` module using `GenServer` as the primary language-first sensory organ.

#### Supervision requirements

- Integrate the new ingestor into `Sensory.Application`, either directly or beneath a rewritten `Sensory.StreamSupervisor`.
- Preserve `:one_for_one` supervision.
- Keep the design actor-oriented with local state only.

#### Required ingestor contract

The ingestor must expose a bounded GenServer contract for continuous raw input, including:

- a public ingestion function for raw byte chunks
- internal ephemeral rolling buffer state
- sliding-window sequence extraction over a configurable or hardcoded window that defaults to 5 bytes
- threshold-gated projection of recurring sequences into Rhizome memory

#### Required ingestor behavior

Implement the ingestor so it:

1. accepts raw binary input without tokenization, parsing, or normalization into words
2. appends bytes into an ephemeral rolling buffer
3. derives overlapping byte windows from that buffer
4. counts sequence frequencies over time
5. emits only sequences that cross a hardcoded activation threshold
6. persists those activations as `PooledSequence` nodes through a new `Rhizome.Memory` entrypoint

Do not preprocess the stream into words, punctuation classes, phonemes, tokens, AST nodes, or grammar categories. The organism must discover structure from byte co-occurrence alone.

### Spatial Pooler requirements

Implement a `Spatial Pooler` within the ingestor rather than as an AST graph reducer.

The pooler must:

- operate directly on raw byte windows
- use a sliding temporal window, defaulting to 5 bytes
- count recurring windows deterministically
- use a hardcoded activation threshold for first-pass concept formation
- treat each activated sequence as an emergent sensory primitive, not a parsed linguistic token

You may keep or rewrite `Sensory.SpatialPooler`, but its semantics must become byte-window pooling rather than AST edge co-occurrence analysis.

### Rhizome persistence requirements

Do not reuse `Rhizome.Memory.persist_pooled_pattern/1` for this work.

Instead, add a new `Rhizome.Memory` entrypoint dedicated to pooled byte sequences. The new API must:

- upsert `PooledSequence` nodes
- persist raw bytes or an encoded byte-window representation
- persist occurrence counts
- persist activation threshold
- persist observed timestamps or equivalent temporal evidence
- use typed graph operations internally rather than requiring the sensory layer to issue raw Memgraph queries

The sensory layer must call the new sequence-specific `Rhizome.Memory` API, not `Rhizome.Native.memgraph_query/1` and not opaque Cypher strings.

You may implement the new memory entrypoint using the existing typed graph helpers such as `upsert_graph_node/1` and `relate_graph_nodes/1`, but the resulting graph model must be `PooledSequence`-oriented, not `PooledPattern`-oriented.

### Sensory perimeter rewrite

Rewrite `Sensory.Perimeter` so the AST/repository ingestion path is no longer the baseline sensory contract.

Requirements:

- remove `eyes` as a valid baseline sensory organ
- remove repository snapshot and source-file AST ingestion as sanctioned baseline surfaces
- make raw-byte linguistic intake the approved sensory path
- keep perimeter validation explicit and typed

Rewrite the public `Sensory` facade so language-first ingestion replaces repository parsing as the primary boundary.

### Explicit prohibitions

The implementation must forbid:

- external NLP APIs
- pre-trained tokenizers
- Tree-sitter parsers
- dependency parsers
- parser wrappers hidden behind new module names
- heuristic text normalization that imports linguistic priors

If a proposed implementation still relies on code-language parsing or word-level tokenization, it is incorrect.

### Test and verification requirements

Update the sensory and Rhizome test surfaces so they match the new ingestion model.

At minimum:

1. Add or rewrite sensory tests to verify:
   - `Sensory.TabulaRasa.Ingestor` starts under the sensory supervision tree
   - byte ingestion maintains an ephemeral buffer
   - the buffer drops old data according to bounded-buffer rules
   - sliding-window pooling over a 5-byte stream yields deterministic counts
   - only sequences at or above the activation threshold are persisted
   - persisted graph records are `PooledSequence`-oriented, not AST- or `PooledPattern`-oriented
2. Rewrite perimeter and facade tests to verify:
   - `Sensory.Perimeter` no longer exposes `eyes` or repository AST ingestion as a valid baseline organ
   - public `Sensory` delegates no longer route to `Sensory.Eyes`
3. Add or rewrite Rhizome tests to verify the new sequence-specific memory entrypoint:
   - validates payload shape
   - projects `PooledSequence` nodes through typed graph operations
   - does not require opaque graph queries from callers
4. Delete or rewrite AST-oriented tests such as:
   - `eyes_test`
   - `ast_accuracy_test`
   - `native_test`
   - `stream_test`
   - `ingestion_test`
   - NIF contract tests that assert parser scheduler wiring
5. Run a repo search and confirm no active `Tree-sitter`, `Sensory.Eyes`, or `parse_to_graph` dependencies remain in `app/sensory` after the rewrite, except in deleted-history references or non-executable documentation explicitly left out of scope.

### Implementation rules

- Make the smallest coherent set of code changes that fully completes the sensory pivot.
- Prefer preserving bounded public contracts where reasonable, but rewrite semantics aggressively where they are still AST-centric.
- Do not leave dead parser files, dead delegates, dead tests, or unreachable perimeter branches behind.
- Keep comments concise and only where they clarify non-obvious ingestion, buffering, or pooling behavior.
- Maintain a biologically framed sensory narrative: byte hearing, emergent sequence formation, and explicit graph wiring through Rhizome.

### Deliverables

Return:

1. The code changes.
2. A short summary of what was deleted, rewritten, and added.
3. The verification steps you ran.
4. Any residual risks if later phases such as STDP coordination, operator feedback, or grammar consolidation are still pending outside `app/sensory`.
