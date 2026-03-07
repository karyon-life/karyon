---
title: "Multi-Version Concurrency Control"
---

The theory of a lock-free, dual-layer topological Rhizome is conceptually elegant, but its physical implementation represents a brutal orchestration challenge. When thousands of concurrent biological cells (Actor Model processes running on the BEAM virtual machine) attempt to rapidly query, generate, and prune millions of edges within a shared Memgraph memory pool, the environment is ripe for catastrophic race conditions.

If Cell A reads a relational state to parse a python file, while the background optimization daemon simultaneously deletes a decaying node that Cell A relied upon, the system experiences digital cognitive dissonance.

## Multi-Version Concurrency Control (MVCC)

Karyon averts process lock-ups and cognitive dissonance through strict architectural reliance on **Multi-Version Concurrency Control (MVCC)**. In a standard database schema, a process locks the row or node it is modifying, forcing all adjacent readers connecting to that memory block to wait. In a reactive intelligence engine running on a 128-thread Threadripper, blocking I/O inherently destroys the organism's agility.

With MVCC, the Rhizome treats memory as immutable facts rather than manipulatable fields.
*   When a perception cell learns a new relationship and updates a graph node in Memgraph, it does not overwrite the old data pointer. It creates an explicit *new* version of that node appended with a newer chronological timestamp.
*   The active execution cells always read the newest available "live" version of the graph across their shared Virtio-fs boundaries and Memory Glia caching layers.
*   Simultaneously, the background optimization daemons safely analyze older, static versions of the graph's history (to identify recursion patterns or extract telemetry) without ever placing a read-lock on the active cells' workspace. 

Only once a daemon finishes mapping a highly optimized version of a long-term Memory subgraph does it perform a fast, atomic pointer swap. The execution cells organically begin reading from this highly efficient pathway on their next cycle with zero observable downtime.

## The Hardware Bottleneck: NUMA Constraints

This massive, asynchronous memory orchestration surfaces an unavoidable hardware constraint. Standard server configurations frequently employ dual-socket Non-Uniform Memory Access (NUMA) topologies. 

If Karyon operates over 128 threads via two physical CPUs (e.g., dual 64-core EPYC), its 512GB of RAM is physically split across the motherboard. Should a cell executing on CPU 1 need to follow a relational graph edge loaded into the RAM banks of CPU 2, that data traversal must cross a high-latency hardware bridge. For a model heavily reliant on continuous, recursive graph traversal over dense matrix math, a dual-socket NUMA bridge heavily starves the CPU cores of data flow.

Consequently, Karyon's architecture specifically demands high-core-count, single-socket topographies (e.g., an AMD Threadripper with an 8-channel memory configuration). Consolidating execution cores to one physical die ensures all threads maintain equal, low-latency access to the entire 512GB Memgraph environment. The 8-channel RAM layout permits the execution cells to branch deep into specialized sub-graphs simultaneously via the `Rustler` bridges without suffocating under memory bandwidth constriction. 
