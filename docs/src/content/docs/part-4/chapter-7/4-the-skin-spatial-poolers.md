---
title: "The Skin (Spatial Poolers)"
---

Deterministic AST parsing handles known source code, and hardcoded network listeners handle known telemetry payloads. But a truly sovereign architecture cannot collapse when presented with an undocumented text protocol, an alien configuration format, or unstructured natural language. It must possess a generic sensory discovery layer that can feel out the boundaries of an unknown structure mathematically.

In the Karyon architecture, this untargeted sensory organ is conceptually modeled as the "Skin." It is a raw, generic interface that converts unstructured environmental noise into structured topological graph nodes without relying on hardcoded pre-processing.

## Theoretical Foundation

When human skin touches an unknown object, it does not instantly classify the object; it registers raw tactile inputs—temperature, pressure, texture—that the brain correlates into a physical boundary. 

Karyon replicates this using **Hebbian Learning** ("cells that fire together, wire together") combined with **Spatial Pooling**—a concept borrowed from Hierarchical Temporal Memory (HTM). Instead of writing a custom parser for a new log format, the generic perception cell ingests the raw byte stream and observes co-occurrence. If String A frequently appears in close proximity to String B under specific conditions, the spatial pooler organically wires a physical graph node binding them together. Over time, the cell reverse-engineers the semantic structure of the alien protocol entirely via statistical proximity.

## Technical Implementation

To achieve this generic sensory translation without bogging down the CPU with endless string-matching loops, Karyon employs a calculated architectural shortcut: quantized, small-parameter models. 

1.  **The Digitized Retina:** The perception cell spins up a heavily quantized (GGUF) small-parameter model (e.g., a 3B Llama or Qwen instance) running strictly on the CPU via `llama.cpp`. 
2.  **Sensory Perimeter Only:** This model is *never* used for internal logic, reasoning, or long-term memory. It acts purely as a transient "sensory organ" to extract entities and syntactic relationships from the chaotic input stream.
3.  **Topological Forging:** Once the small model identifies a potential structural relationship in the unstructured text, the cell's Actor process takes over. It pushes those relationships into the Rhizome graph database, where continuous Hebbian algorithms either strengthen the synaptic connection (if the pattern repeats) or prune it (if it was an anomaly).

## The Engineering Reality

The implementation of generic spatial poolers exposes the harshest hardware constraints of the Karyon architecture. 

Graph traversal for reasoning is intensely memory-bandwidth-bound, but raw sensory inference is brutally compute-bound. Running continuous inference on a 3B model across CPU cores generates immense localized heat and consumes significant clock cycles. If 40 cores are dedicated to sensory inference, those cores cannot be utilized by the Elixir Epigenetic Supervisor for executing logic or stabilizing the memory graph.

This reality necessitates aggressive core-pinning and strict resource segregation. The generic perception cells must be mathematically capped. If they ingest data faster than the underlying hardware can compute the spatial pooling, the resulting CPU saturation will cause prediction latency to spike, ultimately dragging the entire active inference loop to a halt. The organism's metabolism limits how fast it is physically allowed to learn the unknown.

## Summary

The sensory organs—the deterministic Eyes, the passive Ears, and the generic Skin—form the rigid digital membrane of the Karyon organism. They ensure the internal reasoning engine is fed a diet of highly structured, topological data rather than chaotic text strings. With this unified, multimodal understanding of its environment safely mapped into the Rhizome, the organism is equipped to react. This transitions us to the execution phase: the Motor Functions.
