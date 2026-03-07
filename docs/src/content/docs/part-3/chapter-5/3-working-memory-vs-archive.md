---
title: "Working Memory vs Archive"
---

Replacing matrix layers with a continuous topological map introduces an immediate architectural friction point: the conflict between reactive, low-latency execution and massive, immutable data storage. 

If thousands of lightweight Elixir cells are actively parsing code and processing network events, they cannot afford to wait for a database to write thousands of concurrent graph edges to a slow hard drive. Conversely, if all experiences are loaded purely into RAM for execution speed, the system loses its memory upon a power loss or reboot.

Karyon resolves this by strictly separating the Rhizome into two physically discrete layers: the fast **Working Memory** (Memgraph) and the permanent **Temporal Archive** (XTDB).

## The Syntaptic Cleft: Memgraph (In-RAM)

To mimic the immediate signal processing required by a biological nervous system, Karyon uses **Memgraph** as its active, short-term working memory. Memgraph is an entirely in-memory graph database built in C++ that utilizes the Cypher query language.

When a perception cell encounters raw data (like parsing an Abstract Syntax Tree of a repository), it must physically map those semantic relationships into memory instantaneously. By utilizing an 8-channel memory configuration heavily saturated by Rust NIFs (Native Implemented Functions), the Karyon engine weaves these new topological facts deep into the 512GB Memgraph instance without bottlenecking the CPU's execution threads. 

The live working state of the organism—the active execution plans, the immediate mapping of functions during a refactoring task, and the temporary synaptic bounds connecting disparate logic models—resides exclusively in Memgraph. This allows Karyon to hold the entire abstract relational logic of a massive enterprise codebase in active RAM simultaneously. The "thought" happens here, trading disk persistence for absolute throughput.

## The Sleep Cycle: XTDB (NVMe NVCC Archive)

Holding state purely in Memgraph is a volatile execution strategy. Real memory consolidation—the organism's long-term learning—requires moving validated experiences from short-term RAM into an immutable, searchable permanent history. 

This background consolidation acts as Karyon's biological "sleep cycle," completely decoupled from the sensory-processing execution cells.

Karyon achieves long-term archiving utilizing **XTDB**, a temporal graph database backed by fast NVMe SSD storage. XTDB natively uses Multi-Version Concurrency Control (MVCC) and immutable data structures. When an execution cell validates an abstraction and updates its local state context (e.g., inside `.nexical/history/`), the memory daemon sweeps across the high-speed Memgraph RAM matrix to identify these highly trafficked and successful node sequences. 

The daemon then compresses these localized behaviors into new abstract "super-nodes" (chunking) and flushes these hardened topological facts out of RAM and directly into the permanent XTDB archive. Should Karyon reboot, it relies on XTDB to rebuild the basal ganglia of its Memgraph instance, instantiating the memory of its prior configurations from disk back into RAM.
