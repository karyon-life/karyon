# Refactoring Phoenix LiveView OperatorSandbox: The Action-Friction Harness

**Role:** Enterprise Software Architect

**Context:** 
The Karyon AI platform must shift away from open-ended conversational UI testing to a strict, structured, deterministic linguistic testing environment. The current Operator Sandbox is not equipped to provide the high-frequency Action-Friction Endocrine loop required for structural graph learning and regression testing.

**Instructions for the Developer:**

Refactor the Phoenix LiveView `OperatorSandbox` (`app/operator_environment/lib/operator_environment_web/live/operator_sandbox_live/index.ex`) and structurally related components (e.g., `app/core/lib/core/teacher_daemon.ex`) according to the following strict architectural directives:

1. **Forbid Conversational UI:** 
   Completely remove any open-ended text chat inputs, message bubbles, or generic "conversational" interfaces from the `OperatorSandbox`. The system must NOT accept unstructured natural language prompts.

2. **Build a Deterministic 'Action-Friction Harness':** 
   The new UI must act as a deterministic testing harness built specifically for rapid, high-volume regression testing of the temporal graph (Rhizome).

3. **Strict DSL Array Input:** 
   The UI must require and accept strict Domain-Specific Language (DSL) arrays representing structural commands. 
   - Example format: `["ALLOW", "User_A", "READ", "Database_X"]`
   - Implement an input mechanism that guarantees this structured array format before submission (e.g., structured dynamic forms, tokenized input field components, or strict JSON array validation).

4. **Automated Parsing & Traversal:** 
   Upon submission, the LiveView module must automatically parse these arrays and feed them directly into the newly refactored `Sensory.Quantizer`. This step must trigger the internal graph traversal and mapping logic within Karyon.

5. **Explicit 'Friction' Controls:** 
   Provide exactly two explicit UI buttons for the operator to evaluate the system's generated execution path and graph topology:
   - **[Confirm Topology]**: Triggers a positive Endocrine spike (Dopamine analogue), mapped to the `Core.OperatorFeedback` module, locking the temporal edges that led to the response.
   - **[Reject Syntax]**: Triggers a negative Endocrine spike (Nociception/Pain analogue), signaling a logic or syntax failure. This must force the STDP coordinator to decay the synaptic weights in that specific execution path.

**Expected Outcome:** 
The resulting `OperatorSandbox` must function as a high-speed structural curriculum runner. An operator must be able to feed discrete, deterministic DSL sequences into the system, view Karyon's internal structural prediction, and instantly punish or reward the temporal path via the Friction controls without ever typing a full sentence.
