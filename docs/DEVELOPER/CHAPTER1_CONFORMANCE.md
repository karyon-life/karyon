# Chapter 1 Conformance

This document defines the forbidden architectural regressions derived from Part 1 Chapter 1 of the Karyon book source at `docs/src/content/docs/part-1/chapter-1/**`.

## Forbidden Regressions

Do not introduce any of the following into the core reasoning boundary:

- Prompt-response orchestration as the primary planning mechanism.
- Stateless planning that does not depend on graph-backed memory or recovered lineage state.
- Unstructured planning payloads where typed planning contracts should exist.
- Direct ad hoc mutation paths that bypass typed prediction-error persistence.
- Execution that ignores metabolic or ATP budget constraints.
- Learning updates that do not persist durable recovery state for cells.
- New APIs named around prompt, completion, or chat-style interaction inside the planning, execution, or memory boundary.

## Required Invariants

Chapter 1 conformance requires these behaviors:

- Planning is graph-backed and uses typed attractor and step contracts.
- Cells retain and recover lineage state from durable memory.
- Execution respects DNA `atp_requirement` before action.
- Nociception and execution failures persist typed prediction errors through the memory pipeline.

## Enforcement

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app/core && mix chapter1.conformance
```

CI requirement:

- The GitHub Actions workflow `chapter1-conformance.yml` must pass on pushes and pull requests that touch the repository.
