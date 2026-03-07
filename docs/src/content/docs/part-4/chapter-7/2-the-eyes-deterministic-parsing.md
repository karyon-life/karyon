---
title: "The Eyes (Deterministic Parsing)"
---

The most fundamental flaw in using an autoregressive neural network to parse complex structural environments—such as the 10,000 files of a software monorepo—is hallucination. Neural networks are probabilistic inference engines; they do not perceive the definitive source of truth, they predict the most statistically likely sequence of tokens that represents it. When standard AI models attempt to build an internal map of an entire codebase, they frequently invent nonexistent dependencies, hallucinate function signatures, and drop exact references due to context window constraints. 

For an architecture tasked with sovereign engineering, probabilistic perception of structural code is a fatal error. 

## Theoretical Foundation

To operate as a competent systems architect, Karyon must possess a localized, 100% accurate mental model of the source code it intends to manipulate. When a baby is born, it does not spend the first two years computationally deriving the physics of photon ingestion from scratch; it is born with a functioning retina given to it by its genetic code.

In the Karyon framework, the "Eyes" are Perception Cells genetically configured (via YAML DNA) to operate purely as deterministic parsers. They do not employ neural weights to guess at code structure; they algorithmically map the exact syntax.

## Technical Implementation

The deterministic perception cell is instantiated through a Rust Native Implemented Function (NIF) bound to an Elixir Actor process. At its core, the cell utilizes **Tree-sitter**, an incremental parsing system that generates highly performant Abstract Syntax Trees (ASTs).

1.  **The Swarm Trigger:** When a directory-watcher cell detects a massive structural input (e.g., pointing Karyon at a new `/docs/src/` folder), it fires an ambient NATS signal: *"Massive structural input detected."*
2.  **Cellular Activation:** Instantly, the Elixir Epigenetic Supervisor wakes up thousands of dormant Tree-sitter "Eye" cells. Each cell is assigned exactly one file from the repository.
3.  **Microsecond Ingestion:** Across 128 virtual threads, these cells parse the codebase in parallel natively in Rust. Tree-sitter converts the raw ASCII string of a target file into an exact, microsecond-accurate AST.
4.  **Topological Translation:** The cell traverses the AST, translating the deterministic syntax (e.g., `Class -> Method -> Variable`) into topological graph commands. It inserts these structural nodes directly into the high-speed Memgraph Rhizome.

## The Engineering Reality

The computational reality of this process is not bound by GPU VRAM, but entirely by CPU context-switching and lock-free memory contention. 

While Tree-sitter requires almost zero CPU and no VRAM to parse a file, forcing parallel actors to rapidly flush their generated AST nodes into a shared graph creates an immense I/O blast radius. A 100,000-line codebase converted into an AST graph can spawn millions of distinct edges. If Karyon's Rust routines attempt to lock the graph during this insertion, the entire Cytoplasm environment stalls, suffocating active reasoning cells. 

To mitigate this, the Memgraph ingestion occurs strictly via lock-free MVCC batched transactions. The organism "blinks"—taking in a vast visual snapshot of the repository, parsing it concurrently, and committing the topological representation to working memory without blocking the background active inference loops.

## Summary

By offloading the visual ingestion of code to deterministic Tree-sitter cells, Karyon achieves an infallible, localized map of its target environment with negligible metabolic overhead. But static source code is only one layer of reality. To survive, the organism must also perceive dynamic state changes and environmental noise in real-time. This requires the "Ears"—the telemetry and event-listening cells.
