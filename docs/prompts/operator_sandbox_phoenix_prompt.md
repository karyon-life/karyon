# Operator Sandbox Phoenix Prompt

Use this prompt to direct an implementation model to perform the full-stack Phoenix refactor described in [`chat2.xml`](/home/adrian/Projects/nexical/karyon/chat2.xml): delete the Firecracker-based `app/sandbox` execution membrane and replace it with a new `app/operator_environment` Phoenix LiveView application that serves as the real-time Operator Sandbox.

## Prompt

You are refactoring the Karyon repository at `/home/adrian/Projects/nexical/karyon`.

Your objective is to execute the Operator Sandbox pivot described in `chat2.xml`: remove the AWS Firecracker microVM execution membrane and replace it with a new Phoenix LiveView application that acts as the organism's waking-world operator environment for continuous byte input, motor babble observation, biological feedback injection, and live Variational Free Energy telemetry.

### Architectural intent

- Treat `chat2.xml` as the architectural source of truth for this refactor, especially the sections describing the replacement of Firecracker with an Operator Sandbox and the LiveView operator interface contract.
- This is not a terminal emulator, not a code runner, and not a general dashboard retrofit. It is the primary environmental membrane through which the operator conditions the organism while it is awake.
- Preserve the Karyon constraints in `AGENTS.md` and `GEMINI.md`: biology first, actor isolation, no centralized mutable state, no monolithic orchestration, and no direct database manipulation from the UI layer.

### Important repo facts you must honor

- [`app/sandbox/lib/sandbox/application.ex`](/home/adrian/Projects/nexical/karyon/app/sandbox/lib/sandbox/application.ex) currently supervises `Sandbox.RuntimeRegistry` and `Sandbox.VmmSupervisor`.
- [`app/sandbox/lib/sandbox/firecracker.ex`](/home/adrian/Projects/nexical/karyon/app/sandbox/lib/sandbox/firecracker.ex) is still a full Firecracker microVM wrapper.
- `app/sandbox` still contains Firecracker-oriented `Executor`, `Provisioner`, `RuntimeRegistry`, `VmmSupervisor`, and matching tests.
- [`app/dashboard/lib/dashboard_web/live/metabolic_live/index.ex`](/home/adrian/Projects/nexical/karyon/app/dashboard/lib/dashboard_web/live/metabolic_live/index.ex) is the current Phoenix LiveView surface, but it is a metabolic monitor only and currently binds through `Dashboard.PubSub`.
- The repo currently has `NervousSystem.Endocrine` for NATS transport and no existing `NervousSystem.PubSub` module.
- [`app/core/lib/mix/tasks/karyon.baseline.ex`](/home/adrian/Projects/nexical/karyon/app/core/lib/mix/tasks/karyon.baseline.ex) still assumes `:sandbox` is part of the baseline app boot list.

### Non-negotiable runtime constraints

- Completely delete the AWS Firecracker microVM orchestration code.
- Do not retrofit this into `app/dashboard`; scaffold a new Phoenix app at `app/operator_environment`.
- The LiveView must never write directly to Memgraph or XTDB.
- The LiveView must bind to an organism bus surface named `NervousSystem.PubSub`.
- `NervousSystem.PubSub` may wrap the existing NATS/endocrine transport, but it must become the direct organism bus API used by the Operator Sandbox.

### Required deletion scope

Delete the Firecracker execution membrane from `app/sandbox`.

At minimum, remove:

- `Sandbox.Firecracker`
- `Sandbox.Provisioner`
- `Sandbox.Executor`
- `Sandbox.VmmSupervisor`
- `Sandbox.RuntimeRegistry`
- Firecracker-specific tests and any remaining microVM boot/runtime assumptions

If other files in `app/sandbox` still encode Firecracker orchestration or VM lifecycle assumptions, delete or rewrite them so the old execution membrane is fully gone.

### New application scaffold

Scaffold a new Phoenix LiveView application at `app/operator_environment`.

Requirements:

- make it a first-class umbrella app, not a library module inside `app/dashboard`
- give it its own `MixProject`, OTP application, endpoint, router, web module, and LiveView surface
- make it the waking-world membrane that replaces `:sandbox` in direct app boot and baseline task lists

Update app boot/task surfaces that still assume `:sandbox`, especially the current baseline/startup flows, so `:operator_environment` replaces `:sandbox` as the primary environment membrane.

### Required organism bus facade

Create a new `NervousSystem.PubSub` facade.

Requirements:

- define it as the direct organism bus API for the Operator Sandbox
- expose subscribe/broadcast primitives for organism channels such as:
  - motor output
  - telemetry
  - nociception
- wrap the existing NATS/endocrine transport rather than reusing `Dashboard.PubSub`
- allow the LiveView to bind directly to `NervousSystem.PubSub`

Do not treat `NervousSystem.PubSub` as a naming typo. This module does not exist yet; create it explicitly.

### Operator Sandbox LiveView contract

Design one primary LiveView screen with four strict zones.

#### Zone 1: Continuous Byte-Streaming Input

- implement a continuous input field using `phx-keyup`
- stream bytes as the operator types
- do not use a traditional submit form as the primary interaction path

#### Zone 2: Read-Only Motor Babble Output

- render a real-time output stream for motor babble
- make it strictly read-only
- do not allow operator edits in this zone

#### Zone 3: Biological Feedback Array

- provide a visible array of feedback controls
- include buttons or equivalent controls for injecting variable `metabolic.spike` severities
- feedback payloads must be typed numeric severity values, not vague string labels alone

#### Zone 4: Variational Free Energy HUD

- render a live VFE/telemetry HUD
- update it from organism telemetry, not browser-local heuristics
- make the operator able to see the organism's current learning pressure and metabolic state in real time

### Macro-input bundling requirement

Implement macro-inputs over the LiveView websocket, including `Shift+Enter`.

Requirements:

- `Shift+Enter` must bundle:
  - the current text byte stream
  - an immediate nociceptive severity multiplier
- send them as one bundled websocket event
- treat the bundle as one organism-bound event, not two loosely ordered events
- explicitly implement this to prevent race conditions between sensory bytes and pain injection

### LiveView-to-organism wiring

The new LiveView must bind directly to `NervousSystem.PubSub`.

Requirements:

- subscribe to organism channels for motor output and telemetry
- broadcast operator byte input and biological feedback over `NervousSystem.PubSub`
- keep the UI side asynchronous and actor-oriented
- do not use `Dashboard.PubSub` as the operator-environment bus
- do not bypass the organism bus with direct calls into Rhizome or raw storage layers

### UI semantics from chat2.xml

Preserve the behavioral contract described in `chat2.xml`.

Requirements:

- continuous sensory streaming via `phx-keyup`
- strict separation between operator byte input and out-of-band biological feedback
- real-time observation of motor babble
- visible VFE/metabolic state so the operator sees learning pressure in flight
- this is not a chat UI and not a generic admin console; it is a biological conditioning membrane

### Explicit prohibitions

The implementation must forbid:

- Firecracker or microVM orchestration surviving under new names
- retrofitting the operator environment into the existing `app/dashboard` app instead of creating `app/operator_environment`
- direct database writes from the LiveView
- using `Dashboard.PubSub` as the primary organism bus
- traditional form-submit semantics as the only input mechanism

If the implementation keeps `app/sandbox` as an active Firecracker app or routes the new LiveView through `Dashboard.PubSub`, it is incorrect.

### Test and verification requirements

Update the test suite so it matches the Operator Sandbox replacement.

At minimum:

1. Add replacement tests for the sandbox removal to verify:
   - no Firecracker application children remain
   - no sandbox startup path still depends on microVM boot assets
   - no baseline/startup task still expects `:sandbox`
2. Add `operator_environment` tests to verify:
   - the LiveView mounts and renders the four strict zones
   - `phx-keyup` streams bytes continuously
   - motor babble is read-only
   - biological feedback controls emit typed `metabolic.spike` severity payloads
   - `Shift+Enter` sends a bundled byte-stream plus nociception multiplier event
   - the VFE HUD updates from subscribed organism telemetry
3. Add bus-layer tests to verify:
   - `NervousSystem.PubSub` exists and wraps the organism bus under the requested name
   - the LiveView subscribes through `NervousSystem.PubSub`, not `Dashboard.PubSub`
   - operator feedback and motor telemetry route over the organism bus without direct database access
4. Run a repo search and confirm:
   - no active Firecracker or microVM orchestration remains in `app/sandbox`
   - the new LiveView no longer relies on `Dashboard.PubSub`
   - `NervousSystem.PubSub` is the direct operator-environment bus surface

### Implementation rules

- Make the smallest coherent set of code changes that fully completes the Operator Sandbox replacement.
- Prefer preserving Phoenix conventions inside the new app, but do not let existing dashboard patterns force an incorrect architecture.
- Do not leave dead Firecracker files, dead tests, or stale `:sandbox` boot assumptions behind.
- Keep comments concise and only where they clarify the organism bus boundary, strict UI zoning, or bundled websocket semantics.
- Maintain the biological framing: waking-world membrane, byte intake, motor babble, nociceptive feedback, and VFE observability.

### Deliverables

Return:

1. The code changes.
2. A short summary of what was deleted, scaffolded, and rewired.
3. The verification steps you ran.
4. Any residual risks if later dashboard, dream-state, or consolidation flows still depend on the old sandbox assumptions.
