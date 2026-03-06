# Karyon Architecture Book Writing Guidelines

These guidelines define the writing style, structure, and academic conventions to be used when generating content for the "KARYON: The Architecture of a Cellular Graph Intelligence" book. All generated content must stridently adhere to these principles to ensure consistency, authority, and clarity.

## 1. Core Persona and Tone

*   **Authoritative and Objective:** The tone must be that of an expert systems architect and academic researcher. Avoid conversational filler, marketing speak, or colloquialisms. Speak directly to the technical realities and theoretical foundations.
*   **Analytical and Unvarnished:** Present both the advantages and the brutal engineering challenges (the "harsh realities") of the architecture. Do not gloss over complexity, bottlenecks, or trade-offs.
*   **Biologically Grounded:** When using biological metaphors (e.g., cell, organism, memory graph, epigenetic, apoptosis), ground them immediately in their exact digital and mathematical equivalents (e.g., Actor model processes, lock-free XTDB graphs, YAML schemas). The biological metaphor is a structural blueprint, not poetry.
*   **Sovereign and Immutable:** Emphasize the themes of sovereign infrastructure, air-gapped security, deterministic execution, and lock-free concurrency.

## 2. Structural Requirements for Chapters

While each chapter will contain distinct section topics (as outlined in `book-outline.md`), the *overall flow* of the combined sections within a chapter should logically progress through these thematic stages when appropriate:

1.  **Abstract / Introduction:** A concise outline of the chapter's objective and the theoretical concepts it will cover.
2.  **Theoretical Foundation:** The "Why." Explain the mathematical, biological, or architectural theory driving the design choice before showing the implementation.
3.  **Technical Implementation:** The "How." Detail the concrete system architecture, data structures, algorithms, and infrastructure (e.g., Elixir supervisors, Rust memory pointers, ZeroMQ routing).
4.  **The Engineering Reality (Trade-offs):** A dedicated section outlining the primary bottlenecks, risks, or computational costs of the approach (e.g., broadcast storms, NVMe I/O limits, NUMA constraints).
5.  **Summary / Transition:** A brief conclusion that recaps the core takeaway and logically bridges to the next chapter.

*Note: Do not literally enforce identical section files for every chapter. Adapt these thematic requirements naturally into the specific bullet points provided in the syllabus.*

## 3. Writing Style and Formatting

*   **Clarity over Complexity:** Use precise, declarative sentences. Avoid passive voice when describing system actions (e.g., use "The Epigenetic Supervisor spawns cells," not "Cells are spawned by the Epigenetic Supervisor").
*   **Structured Information:** Use bulleted lists, numbered sequences, and comparison tables extensively to break down complex mechanisms or contrast Karyon with traditional AI (e.g., Cellular AI vs. Transformers).
*   **Progressive Disclosure:** Introduce high-level concepts before diving into the mathematical or code-level specifics.
*   **Terminology Consistency:** Adhere strictly to the defined glossary. Do not use synonyms for core components (use *Karyon*, not "the engine"; use *Rhizome*, not "the database").

## 4. Technical and Academic Constraints

*   **No "Magic":** Refrain from describing AI behaviors as emergent magic. Explain the exact algorithmic or topological mechanism that creates the behavior (e.g., explain curiosity as *epistemic foraging for low-confidence graph edges*, not "the AI wants to know").
*   **Code and Schemas:** When providing code snippets, architectural diagrams, or YAML configurations, ensure they are Syntactically valid, heavily commented, and directly relevant to the surrounding text. Use concise, illustrative snippets rather than overwhelming blocks of code.
*   **Hardware Realism:** Always contextually frame the software architecture against the physical hardware constraints (e.g., Threadripper L3 cache, 8-channel ECC RAM, Virtio-fs overhead).
*   **Citations, Prior Art, and Comparisons:** Actively contrast Karyon's approach with existing industry models (e.g., how the spatial pooler differs from a transformer attention head). Provide citations and acknowledge foundational theories when applicable (e.g., Hebbian learning, Active Inference, Actor Model, Multi-Version Concurrency Control).

## 5. Artifact Generation Directives

When acting as the author generating a new section or chapter:

1.  **Reference the Source Material:** Always refer back to `chat.xml` to ground your explanations in the explicit decisions, phrasing, and mathematical logic discussed during the architectural design phase. Do not invent net-new core mechanisms; extrapolate deeply from the established logs.
2.  **Review the Outline:** Ensure the generated content strictly aligns with the established `book-outline.md`.
3.  **Contextual Awareness:** Maintain continuity with preceding chapters. Do not re-explain foundational concepts that were covered earlier unless necessary for context.
4.  **Target Length:** Ensure the depth of technical explanation justifies the word count. Expand on the *mechanics* rather than adding fluff to reach the ~80k word target.
5.  **Markdown Standards:** Output using standard GitHub-flavored markdown, suitable for Astro Starlight rendering. Use appropriate heading levels (starting at H2 for section headers), code blocks with language tags, and blockquotes for emphasis.

## 6. Key Terminology Mapping

Ensure consistent usage of these terms:
*   **Karyon:** The immutable Elixir/Rust core engine.
*   **Rhizome:** The shared temporal memory graph (Memgraph/XTDB).
*   **Cytoplasm:** The BEAM (Erlang VM) concurrency environment.
*   **Organelles:** Rust Native Implemented Functions (NIFs).
*   **DNA:** Declarative YAML configuration schemas.
*   **Apoptosis:** Programmed cell death based on utility weights.
*   **Metabolism:** Compute/Resource constraints (CPU, RAM, I/O).
