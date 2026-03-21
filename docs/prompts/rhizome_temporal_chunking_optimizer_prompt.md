# Rhizome Temporal Chunking Optimizer Prompt

Use this prompt to direct an implementation model to perform the optimizer/consolidation rewrite described in [`chat3.xml`](/home/adrian/Projects/nexical/karyon/chat3.xml): delete the mathematically incorrect Louvain-style language clustering path and replace it with directed temporal sequence chunking over `FOLLOWED_BY` paths so Karyon can preserve syntax order during sleep-cycle abstraction.

## Prompt

You are refactoring the Karyon repository at `/home/adrian/Projects/nexical/karyon`.

Act as a Graph Database and Rust optimization expert working on a Memgraph-backed Rust NIF for Karyon.

Your objective is to execute the language-memory optimizer rewrite described in `chat3.xml`: remove the undirected co-occurrence clustering path from `app/rhizome/native/rhizome_nif/src/optimizer.rs`, replace it with a directed temporal sequence optimizer based on `FOLLOWED_BY` paths, and update the coupled Elixir consolidation and test surfaces so the Rhizome sleep cycle becomes internally consistent again.

## Architectural intent

- Treat `chat3.xml` as the architectural source of truth for this refactor, especially the sections that explicitly state the current implementation is mathematically wrong for language because it treats syntax as undirected co-occurrence clusters.
- This is not a generic graph cleanup. It is the structural rewrite required to preserve token order so Karyon can learn language as temporal sequence rather than bag-of-words adjacency.
- Preserve the Karyon constraints in `AGENTS.md` and `GEMINI.md`: biology first, no centralized mutable state, no scheduler-hostile Elixir graph walks, no weakening of OTP fault tolerance, and no bypassing the typed Rhizome boundaries.

## Important repo facts you must honor

- [`app/rhizome/native/rhizome_nif/src/optimizer.rs`](/home/adrian/Projects/nexical/karyon/app/rhizome/native/rhizome_nif/src/optimizer.rs) currently exports `optimize_graph/0` as a Rustler NIF on `DirtyCpu`. Preserve that entrypoint and scheduler choice.
- `optimizer.rs` currently contains `identify_louvain_communities`, queries `CO_OCCURS_WITH`, and emits a success message that still describes Louvain community detection. That entire path is wrong for language.
- [`app/rhizome/lib/rhizome/consolidation_manager.ex`](/home/adrian/Projects/nexical/karyon/app/rhizome/lib/rhizome/consolidation_manager.ex) duplicates the same mistake: it contains a local `identify_louvain_communities/1`, queries `CO_OCCURS_WITH`, and persists `GrammarSuperNode`s using unordered community semantics.
- [`app/rhizome/test/rhizome/optimizer_complex_test.exs`](/home/adrian/Projects/nexical/karyon/app/rhizome/test/rhizome/optimizer_complex_test.exs), [`app/rhizome/test/rhizome/consolidation_manager_test.exs`](/home/adrian/Projects/nexical/karyon/app/rhizome/test/rhizome/consolidation_manager_test.exs), [`app/rhizome/test/rhizome/sleep_consolidation_test.exs`](/home/adrian/Projects/nexical/karyon/app/rhizome/test/rhizome/sleep_consolidation_test.exs), and [`app/rhizome/native/rhizome_nif/src/tests.rs`](/home/adrian/Projects/nexical/karyon/app/rhizome/native/rhizome_nif/src/tests.rs) currently encode Louvain/co-occurrence behavior as correct. They must be rewritten.
- [`app/rhizome/test/rhizome/nif_contract_test.exs`](/home/adrian/Projects/nexical/karyon/app/rhizome/test/rhizome/nif_contract_test.exs) already asserts dirty-scheduler usage and forbids `.unwrap()` and `.expect()` in production NIF files. Preserve those guarantees.
- [`bin/valgrind_check.sh`](/home/adrian/Projects/nexical/karyon/bin/valgrind_check.sh) already exists and must be used for strict Rhizome NIF memory leak checks. This rewrite is incomplete unless Valgrind passes.

## Non-negotiable runtime constraints

- Keep heavy graph mining and graph mutation in Rust, not in Elixir loops.
- Keep the public NIF boundary `optimize_graph/0`.
- Keep `optimize_graph/0` on `DirtyCpu`.
- Do not use `.unwrap()` or `.expect()` in production Rust code.
- Return clean `{:ok, message}` results when no candidate temporal sequences exist.
- Return structured errors for Memgraph query failures, row decode failures, and persistence failures.
- Do not panic.
- Do not keep any active Louvain/community-detection path behind feature flags, helper functions, or dead compatibility branches.

## Required Rust optimizer rewrite

Completely rewrite [`app/rhizome/native/rhizome_nif/src/optimizer.rs`](/home/adrian/Projects/nexical/karyon/app/rhizome/native/rhizome_nif/src/optimizer.rs).

### Mandatory deletions

You must delete all of the following:

- the `identify_louvain_communities` function
- all helper logic that builds undirected communities from weighted edges
- all `CO_OCCURS_WITH`-driven optimizer query assumptions
- all success text that claims Louvain/community optimization occurred
- all Rust tests that validate community detection

If `identify_louvain_communities` remains anywhere in the active optimizer implementation, the refactor is incorrect.

### Required replacement algorithm

Implement a **Sequential Pairwise Chunking** algorithm.

The algorithm must:

1. Query Memgraph for directed temporal triples shaped like:

```cypher
MATCH (a:PooledSequence)-[ab:FOLLOWED_BY]->(b:PooledSequence)-[bc:FOLLOWED_BY]->(c:PooledSequence)
WHERE a.source = 'operator_environment'
  AND b.source = 'operator_environment'
  AND c.source = 'operator_environment'
RETURN id(a) AS start_id,
       id(b) AS middle_id,
       id(c) AS end_id,
       coalesce(ab.weight, 1.0) AS ab_weight,
       coalesce(bc.weight, 1.0) AS bc_weight,
       coalesce(ab.occurrences, 1) AS ab_occurrences,
       coalesce(bc.occurrences, 1) AS bc_occurrences
```

2. Treat sequence order as non-negotiable:
   - `A -> B -> C` and `C -> B -> A` must be different sequences.
   - `A -> B` may be chunked without implying `B -> A`.
3. Score candidate sequences by deterministic support derived from frequency, edge weight, occurrences, or a clearly documented combination of those signals.
4. Ignore low-support chains.
5. Collapse only high-frequency sequences into a single `GrammarSuperNode`.
6. Preserve the exact ordered lineage of each collapsed chunk.

You may implement chunking in pairwise stages internally, but the resulting behavior must preserve full ordered sequence semantics. The new optimizer must behave like sequence compression over graph paths, not clique/community extraction.

### Required abstraction persistence

When a high-frequency temporal sequence is selected, persist a `GrammarSuperNode` that represents the ordered chunk.

Requirements:

- Keep `GrammarSuperNode` as the abstraction label.
- Do not store only unordered member ids.
- Persist ordered sequence metadata sufficient to reconstruct the chunk exactly.
- The graph model must explicitly preserve sequence order, either through:
  - ordered metadata on the `GrammarSuperNode`, or
  - order-aware abstraction edges / edge properties, or
  - both.

At minimum, persist semantics equivalent to:

- `kind: "temporal_grammar_chunk"`
- `source: "operator_environment"`
- `sequence_length`
- `support`
- `created_at`
- `observed_at`
- ordered member lineage

Do not reuse the old `community_size`-only abstraction model as if it were sequence-aware.

### Required success behavior

The NIF result message must describe temporal chunking, not Louvain/community detection.

Examples of acceptable success semantics:

- no sequence candidates found
- temporal chunking complete
- N temporal grammar chunks created

Examples of unacceptable success semantics:

- Louvain optimization complete
- community detection complete
- clustered pooled-sequence communities

## Required coupled Elixir rewrite

Update [`app/rhizome/lib/rhizome/consolidation_manager.ex`](/home/adrian/Projects/nexical/karyon/app/rhizome/lib/rhizome/consolidation_manager.ex) so it no longer duplicates or depends on Louvain behavior.

Requirements:

- delete the local `identify_louvain_communities/1` path
- remove `CO_OCCURS_WITH` query assumptions from the active grammar-consolidation path
- stop persisting unordered GrammarSuperNodes inside Elixir
- let the Rust optimizer own temporal chunk discovery and ordered grammar abstraction
- keep `ConsolidationManager` as the sleep-cycle orchestrator, but make it delegate to the Rust temporal optimizer rather than reimplementing graph clustering locally

If Elixir still computes unordered communities or builds GrammarSuperNodes from `CO_OCCURS_WITH`, the refactor is incorrect.

## Test and verification requirements

Rewrite the test surfaces that currently encode the wrong model.

### Rust unit tests

Rewrite [`app/rhizome/native/rhizome_nif/src/tests.rs`](/home/adrian/Projects/nexical/karyon/app/rhizome/native/rhizome_nif/src/tests.rs) so it verifies:

- ordered sequence detection distinguishes `A -> B -> C` from permutations
- low-support temporal chains are ignored
- chunking is stable for repeated input
- empty input or no qualifying sequence returns graceful success semantics
- no remaining tests depend on `identify_louvain_communities`

### Rhizome integration tests

Rewrite [`app/rhizome/test/rhizome/optimizer_complex_test.exs`](/home/adrian/Projects/nexical/karyon/app/rhizome/test/rhizome/optimizer_complex_test.exs) and related consolidation tests so they:

- seed `PooledSequence` nodes connected by `FOLLOWED_BY`
- verify `optimize_graph/0` creates at least one `GrammarSuperNode` for repeated ordered paths
- verify abstraction metadata or edges preserve order
- verify `CO_OCCURS_WITH`-only fixtures no longer define correctness

Update consolidation tests so they assert:

- the sleep cycle no longer searches for Louvain communities
- the consolidation path cleanly delegates to the temporal optimizer

### NIF safety and contract tests

Keep and satisfy the existing assertions that:

- `optimize_graph/0` stays on `DirtyCpu`
- production Rust code avoids `.unwrap()` and `.expect()`

### Memory leak verification

You must run the existing Valgrind script:

```bash
bin/valgrind_check.sh
```

This change is incomplete unless the Rhizome NIF passes the existing Valgrind memory profiling path.

## Explicit prohibitions

The implementation must forbid:

- any active Louvain or community-detection helper in the optimizer path
- any active `CO_OCCURS_WITH`-based grammar abstraction path
- any unordered abstraction logic presented as language-sequence understanding
- any Elixir fallback that silently reintroduces the old community model
- panic-only control flow in production Rust
- skipping Valgrind verification

If the resulting system still treats syntax as undirected co-occurrence, it is incorrect.

## Implementation rules

- Make the smallest coherent set of changes that fully migrates the optimizer/consolidation path from unordered clustering to ordered temporal chunking.
- Preserve public boundaries where possible, but rewrite the mathematical core aggressively.
- Keep comments concise and only where they clarify non-obvious sequence scoring, chunk persistence, or BEAM-safety behavior.
- Maintain the biological framing: sleep-cycle consolidation, structural chunking, grammar abstraction, and temporal sequence memory.

## Deliverables

Return:

1. The code changes.
2. A short summary of what Louvain/co-occurrence logic was deleted and what temporal chunking logic replaced it.
3. The verification steps you ran, including the Valgrind command.
4. Any residual risks if later phases such as STDP targeting or operator feedback still assume unordered graph abstractions.
