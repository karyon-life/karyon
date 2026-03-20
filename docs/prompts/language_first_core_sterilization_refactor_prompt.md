# Language-First Core Sterilization Refactor Prompt

Use this prompt to direct an implementation model to perform the Phase 1 refactor described in [`chat2.xml`](/home/adrian/Projects/nexical/karyon/chat2.xml): sterilize the Karyon nucleus of software-engineering priors and reset `app/core` toward tabula rasa linguistic grounding.

## Prompt

You are refactoring the Karyon repository at `/home/adrian/Projects/nexical/karyon`.

Your objective is to execute the Phase 1 "Core Sterilization & Epigenetic Reset" pivot described in `chat2.xml`: remove software-engineering bias from the core, replace code-centric maturation with language-grounding maturation, and keep the organism biologically framed, metabolically constrained, and OTP-compliant.

### Architectural intent

- Treat `chat2.xml` as the architectural source of truth for this refactor, especially the discussion that pivots Karyon away from software engineering and toward language understanding, conversational feedback, babbling, phoneme grounding, grammar consolidation, and semantic grounding.
- This is not a code-execution enhancement. It is a sterilization pass that removes software-engineering scaffolding from the nucleus and establishes a baseline for language-first development.
- Preserve the Karyon constraints in `AGENTS.md` and `GEMINI.md`: biology first, no centralized global state, no business-logic monoliths, no weakening of OTP fault tolerance, and no relaxation of metabolic governance.

### Non-negotiable runtime constraints

- Preserve `Core.Application` as an OTP application using strict `:one_for_one` supervision.
- Preserve `Core.MetabolicDaemon` as a supervised child with its existing admission, pressure, torpor, and apoptosis role unchanged.
- Do not introduce global registries, synchronous orchestration bottlenecks, or supervision strategies other than `:one_for_one`.
- Do not weaken or remove existing `MetabolicDaemon` constraints to make the refactor easier.

### Important repo fact you must honor

- The modules `Core.ObjectiveManifest`, `Core.AbstractIntent`, and `Core.CrossWorkspaceArchitect` are not currently direct children in [`app/core/lib/core/application.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/core/application.ex).
- Therefore, the requirement to "remove them from the `Core.Application` supervision tree" must be implemented by preserving the current child list and eliminating any stale expectations, runtime references, validations, aliases, tests, or maturity contracts that treat those modules as active core limbs.

### Required code changes

1. Delete the following modules entirely:
   - `app/core/lib/core/objective_manifest.ex`
   - `app/core/lib/core/abstract_intent.ex`
   - `app/core/lib/core/cross_workspace_architect.ex`
2. Remove all direct and indirect references to those modules across `app/core`, including:
   - aliases
   - `Code.ensure_loaded?` checks
   - objective-manifest and cross-workspace maturity surfaces
   - lifecycle blockers and evidence fields
   - tests and validation commands
3. Inspect dependent modules and rewrite them so the sterilized core still compiles and its contracts remain coherent. At minimum, evaluate and update:
   - `app/core/lib/core/maturation_lifecycle.ex`
   - `app/core/lib/core/operational_maturity.ex`
   - any tests, support files, or conformance surfaces that mention the deleted modules

### DNA sterilization requirements

Purge software-engineering DNA from both DNA surfaces:

- `priv/dna`
- `app/core/priv/dna`

Delete engineering-oriented DNA specs, including any cells centered on:

- software architecture
- code parsing
- Tree-sitter or AST extraction
- Firecracker or executor-driven code mutation
- patching, compiling, or test-running as a baseline cell behavior

This purge explicitly includes examples such as:

- `priv/dna/rust_architect.yml`
- `priv/dna/python_executor.yml`
- `app/core/priv/dna/architect_planner.yml`
- `app/core/priv/dna/eye_python.yml`
- `app/core/priv/dna/motor_firecracker.yml`

If additional DNA files still encode software-engineering priors, remove or rewrite them so the post-refactor baseline DNA set is language-first rather than code-first.

### New baseline DNA files

Create these three new baseline DNA YAML specs in the canonical shared DNA surface at `priv/dna`:

- `priv/dna/sensory_pooler_cell.yml`
- `priv/dna/motor_babble_cell.yml`
- `priv/dna/tabula_rasa_stem_cell.yml`

Design them as follows:

1. `sensory_pooler_cell.yml`
   - Purpose: raw text or byte ingestion, pooled sequence detection, short-term sensory clustering
   - Allowed actions should be language-grounding oriented, not code-oriented
   - No parser shortcuts, no pre-tokenized NLP assumptions, no Tree-sitter, no AST parser fields
   - Subscriptions and synapses should remain compatible with the organism's decentralized messaging model

2. `motor_babble_cell.yml`
   - Purpose: bounded text emission and exploratory babbling
   - Must not include compile, patch, execute, or provision actions
   - Should remain metabolically constrained and suitable for low-stakes exploratory output

3. `tabula_rasa_stem_cell.yml`
   - Purpose: blank-slate coordination for linguistic grounding, prediction, pruning, and early-stage learning
   - Should encode strong metabolic sensitivity and avoid any software-architecture priors
   - Must not imply preloaded code intelligence, cross-workspace planning, or engineering specialization

Keep the YAML shape compatible with the existing DNA conventions already used in this repository unless a field is clearly engineering-specific and should be removed or renamed.

### Maturation lifecycle rewrite

Rewrite `app/core/lib/core/maturation_lifecycle.ex` to replace the current engineering curriculum with a four-stage linguistic grounding pipeline.

#### Required phase names

- `babbling`
- `phoneme_grounding`
- `grammar_consolidation`
- `semantic_grounding`

#### Contract requirements

- Keep `report/1` as the public entrypoint.
- Preserve the overall report shape style:
  - `schema`
  - `overall`
  - `lifecycle`
  - `phases`
- You may bump the schema version if needed to reflect the semantic break from engineering maturation to linguistic maturation.
- Replace the current "Baseline Diet" and "Execution Telemetry" semantics, validations, objectives, blockers, and evidence fields with language-grounding equivalents.
- Remove all dependence on `Core.ObjectiveManifest` and any objective-manifest root directory assumptions.

#### Phase intent

Implement the phase semantics so they reflect a tabula rasa linguistic curriculum:

1. `babbling`
   - raw sensory intake and exploratory output exist
   - the organism can emit bounded babble and ingest raw text or byte streams
   - blockers should describe missing linguistic intake/output primitives, not missing baseline artifact capture

2. `phoneme_grounding`
   - pooled sensory patterns can be stabilized into recurring low-level language units
   - blockers should reflect missing grounding evidence, pattern stabilization, or sensory-memory correlation

3. `grammar_consolidation`
   - sleep-like or offline consolidation can abstract recurring linguistic structure
   - blockers should describe missing consolidation or structural abstraction capacity

4. `semantic_grounding`
   - grounded forms can be linked to stable meaning through feedback and pruning
   - blockers should describe missing semantic feedback, operator-guided correction, or durable grounding evidence

Use validation strings, objectives, blockers, and evidence fields that match the new language-first contract instead of the deleted code-first curriculum.

### Operational maturity rewrite

Rewrite downstream maturity surfaces that still depend on deleted software-engineering semantics, especially `app/core/lib/core/operational_maturity.ex`.

Requirements:

- Remove references to objective manifests and cross-workspace architecture from the sterilized baseline.
- Remove validation commands that depend on deleted module test suites.
- Preserve bounded observability and service-health reporting.
- Keep the maturity surface coherent with a language-first baseline rather than a software distribution blueprint.

### Test and verification requirements

Update the test suite so it matches the new sterilized core.

At minimum:

1. Delete or rewrite tests that target:
   - `Core.ObjectiveManifest`
   - `Core.AbstractIntent`
   - `Core.CrossWorkspaceArchitect`
2. Rewrite maturation lifecycle tests to assert:
   - the four new phase keys
   - the new blockers and evidence semantics
   - the updated schema if you bump it
3. Verify that `Core.Application` still boots with:
   - `:one_for_one` supervision
   - `Core.MetabolicDaemon` intact as a supervised child
4. Verify that the sterilized baseline DNA set contains no engineering-oriented parser, executor, compile, patch, or code-mutation permissions.
5. Run a repo search and confirm there are no remaining `ObjectiveManifest`, `AbstractIntent`, or `CrossWorkspaceArchitect` references inside `app/core`.

### Implementation rules

- Make the smallest coherent set of code changes that fully completes the sterilization pass.
- Prefer preserving existing public function shapes when possible, but rewrite internal semantics aggressively where they are still code-centric.
- Do not introduce placeholder engineering abstractions under new names.
- Do not leave dead files, dead tests, or unreachable maturity branches behind.
- Keep comments concise and only where they clarify non-obvious biological or lifecycle intent.

### Deliverables

Return:

1. The code changes.
2. A short summary of what was deleted, rewritten, and added.
3. The verification steps you ran.
4. Any residual risks if there are remaining language-first phases not yet implemented outside `app/core`.
