# Karyon Operations

> This document is auto-generated from the Karyon docs source.

# Phase 6 Baseline Measurements

This document records the local baseline harness used for Phase 6.

## Harness

Run from the repository root:

```bash
cd app
mix karyon.baseline
```

The command writes a JSON artifact under:

```text
artifacts/benchmarks/
```

Measured workloads:

- cell spawn throughput via `Core.StressTester`
- local synapse messaging throughput and end-to-end latency
- sensory `parse_to_graph/2` throughput
- consolidation control-plane cost via `Rhizome.ConsolidationManager.run_once/1`

## Notes

- The consolidation metric is a control-plane baseline using a stubbed native module.
- It measures consolidation orchestration cost, not external Memgraph or XTDB service latency.
- Messaging is measured on localhost through the current ZeroMQ path.
- Spawn throughput depends on the current BEAM scheduler count and host pressure.

## Latest Baseline

Artifact:

```text
app/artifacts/benchmarks/phase6_baseline_20260317.json
```

Environment:

- recorded at `2026-03-17T05:32:58.906102Z`
- host architecture `x86_64-pc-linux-gnu`
- OTP `28`
- Elixir `1.19.5`
- `MIX_ENV=dev`
- schedulers online `4`

Results:

| Workload                         | Configuration                                  | Result                                                               |
| -------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------- |
| Cell spawn throughput            | `spawn_count=100`                              | `29.74 cells/s` over `3362 ms`                                       |
| Messaging throughput             | `message_count=500`                            | `7085.46 msg/s`, `141.13 us` average end-to-end latency over `71 ms` |
| Sensory parse throughput         | `parse_iterations=100`, `sample_size_bytes=32` | `3147.62 ops/s`, `0.318 ms` average latency over `32 ms`             |
| Consolidation control-plane cost | `consolidation_iterations=20`                  | `0.15 ms` average cycle, `2 ms` max, `0 ms` min, `21 ms` total       |

Run notes:

- `Core.StressTester` spawned all `100` requested cells.
- Spawn pressure after completion was `medium` with run queue `1`.
- Consolidation ran in `stubbed_control_plane` mode to isolate orchestration cost from external service latency.
- The run emitted non-blocking local-environment warnings for unbound scheduler binding, missing `inotify-tools`, and dashboard asset version drift. Those warnings did not prevent artifact generation.

---

# Production Capacity And SLOs

This document defines the current validated operating envelope for Karyon based on the Phase 6 baseline and recovery artifacts.

It is intentionally conservative. The current measurements come from a single-node local environment and should be treated as the minimum proven envelope, not an upper bound.

## Validated Environment

The current envelope is based on these measured runs:

- baseline throughput artifact: `app/artifacts/benchmarks/phase6_baseline_20260317.json`
- recovery artifact: `app/artifacts/benchmarks/phase6_recovery_20260317.json`

Measured host/runtime context:

- architecture: `x86_64-pc-linux-gnu`
- OTP: `28`
- Elixir: `1.19.5`
- schedulers online: `4`
- environment: `MIX_ENV=dev`

Dependencies validated during service-backed runs:

- Memgraph
- XTDB v2 over PG-wire
- NATS
- Firecracker host toolchain and network helper

## Current Operating Envelope

The following is the current minimum proven envelope for one node with four online schedulers:

| Area                         | Current validated level | Notes                                                                                                  |
| ---------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------ |
| Cell spawn throughput        | `29.74 cells/s`         | measured from `100` spawns over `3362 ms`                                                              |
| Local synapse messaging      | `7085.46 msg/s`         | average end-to-end latency `141.13 us` for `500` messages                                              |
| Sensory parse throughput     | `3147.62 ops/s`         | average parse latency `0.318 ms` for `100` iterations                                                  |
| Consolidation orchestration  | `0.15 ms` average cycle | stubbed control-plane only, excludes Memgraph and XTDB service latency                                 |
| Supervised component restart | `51 ms`                 | validated for `Core.MetabolicDaemon`, `NervousSystem.PainReceptor`, and `Rhizome.ConsolidationManager` |
| Cell apoptosis recovery      | `51 ms`                 | includes XTDB-backed belief rehydration                                                                |

## Initial SLOs

These SLOs are the current production targets. They should be met before calling a node healthy for steady-state operation.

### Availability

- Dashboard liveness: `>= 99.9%`
- Dashboard readiness when dependencies are healthy: `>= 99.5%`
- Dependency-ready organism state for Memgraph, XTDB, and NATS: `>= 99.5%`

### Recovery

- supervised child restart time: `p95 <= 250 ms`
- cell apoptosis plus belief recovery time: `p95 <= 250 ms`
- readiness recovery after a single supervised child failure: `<= 5 s`

These targets leave headroom over the currently measured `51 ms` recovery time while remaining strict enough to catch regressions.

### Throughput And Latency

- cell spawn throughput floor: `>= 20 cells/s`
- local synapse throughput floor: `>= 5000 msg/s`
- average local synapse end-to-end latency: `<= 1 ms`
- sensory parse throughput floor: `>= 2000 ops/s`
- average sensory parse latency: `<= 1 ms`

These are release gates, not saturation goals. Falling below them means the node should be treated as degraded.

## Alert Thresholds

Operators should page or take the node out of rotation when any of the following occurs:

- `/health/ready` returns `503` for more than `5 minutes`
- supervised component restart exceeds `250 ms` in repeated recovery tests
- cell recovery exceeds `250 ms` in repeated recovery tests
- average synapse latency exceeds `1 ms` under the baseline workload
- sensory parse average latency exceeds `1 ms` under the baseline workload
- cell spawn throughput drops below `20 cells/s` under the baseline workload

## Known Constraints

The current envelope is limited by the quality of the measured environment:

- baseline throughput was measured in `dev`, not a packaged prod release
- consolidation timing excludes real optimizer and external graph-service latency
- the recovery suite does not currently invoke `Rhizome.Native.optimize_graph/0` because the current NIF can panic on live graph data
- `PainReceptor` restart currently emits a transient `:eaddrinuse` retry before the replacement `:pain_synapse` binds successfully
- no multi-node or cross-host network envelope has been measured yet

## How To Re-Measure

Baseline throughput:

```bash
cd app
env PATH=/tmp/protoc/bin:$PATH mix karyon.baseline \
  --spawn-count 100 \
  --message-count 500 \
  --parse-iterations 100 \
  --consolidation-iterations 20 \
  --output artifacts/benchmarks/phase6_baseline_$(date +%Y%m%d).json
```

Recovery validation:

```bash
cd app/core
mix test test/core/recovery_chaos_integration_test.exs --include external
```

After re-measuring, update this document and the referenced artifact paths before changing the published SLOs.

---

# Genetic Blueprint Guide

This guide details the process of authoring and managing Karyon "DNA"—the declarative YAML configurations that define cellular behavior and constraints.

## YAML Schema Overview

Karyon DNA files are stored in `app/config/genetics/`. Each file defines the structural and behavioral properties of a cell.

```yaml
version: "1.0"
cell_type: "motor" # [stem, sensory, motor]
capabilities:
  - "io_execution"
  - "graph_access"
synapses:
  - topic: "prediction_errors"
    hwm: 1 # Zero-buffer constraint
  - topic: "telemetry"
    hwm: 10
metabolics:
  cpu_limit_ms: 50
  mem_limit_mb: 128
  apoptosis_on_starvation: true
```

### Hierarchy of Identity

1. **cell\_type**: Defines the basic behavioral template (`Core.StemCell`).
2. **capabilities**: Logic gates that enable or disable specific operational modules (e.g., `Sensory.Native`).
3. **synapses**: ZeroMQ topics the cell subscribes to. Note that `hwm: 1` is mandated for standard predictive coding synapses.

## Differentiation Strategies

### Sensory Cells

Sensory cells ingest external data (code, logs) and convert them into graph topologies.

- **DNA Requirement**: Must include `sensory_perception` capability.
- **Synapse Target**: Usually publishes to `topology_updates`.

### Motor Cells

Motor cells execute sovereign code within Firecracker microVMs.

- **DNA Requirement**: Must include `io_execution` and strict `cpu_limit_ms`.
- **Constraint**: Should never have `graph_access` enabled during active execution phases.

## Validation Bounds

The `Core.YamlParser` enforces strict validation. Corrupted or out-of-bounds configurations will trigger immediate cellular termination on boot to prevent structural instability in the Rhizome.

---

# Health And Response Runbook

This runbook covers the operator-facing health surfaces exposed by the dashboard service.

## Endpoints

### Liveness

```bash
curl -s http://127.0.0.1:4000/health/live
```

Expected response:

- HTTP `200`
- `status: "ok"`
- release metadata
- node identity

This only proves the web process is running and able to serve requests.

### Readiness

```bash
curl -s http://127.0.0.1:4000/health/ready
```

Expected response:

- HTTP `200` when Memgraph, XTDB, and NATS probes are all up
- HTTP `503` when any required dependency is down

Payload includes per-service status and probe detail from `Core.ServiceHealth`.

### Full Status

```bash
curl -s http://127.0.0.1:4000/health/status | jq
```

Expected payload:

- release metadata
- dependency status for `memgraph`, `xtdb`, and `nats`
- runtime fields:
  - `beam_schedulers`
  - `uptime_ms`
  - `dashboard_server`

## Response Guide

### `live` is `200`, `ready` is `503`

The dashboard is running, but the organism is not dependency-ready.

Check:

```bash
docker ps
docker logs karyon_memgraph
docker logs karyon_xtdb
docker logs karyon_nats
```

Then verify configured endpoints:

```bash
env | grep '^KARYON_'
```

Most likely causes:

- Memgraph unavailable or wrong Bolt URL
- XTDB unavailable or wrong PG-wire URL
- NATS unavailable or wrong client URL

### `status.services.xtdb.status == "down"`

Likely XTDB outage or schema/query-path failure.

Actions:

```bash
docker logs karyon_xtdb
curl -i http://127.0.0.1:8080/
```

If XTDB is healthy but readiness is still failing, inspect the configured `KARYON_XTDB_URL`.

### `status.services.memgraph.status == "down"`

Likely Memgraph outage or wrong credentials.

Actions:

```bash
docker logs karyon_memgraph
```

Verify:

- `KARYON_MEMGRAPH_URL`
- `KARYON_MEMGRAPH_USERNAME`
- `KARYON_MEMGRAPH_PASSWORD`

### `status.services.nats.status == "down"`

Likely NATS unreachable or listener not accepting connections.

Actions:

```bash
docker logs karyon_nats
```

Verify:

- `KARYON_NATS_URL`
- nociception/endocrine connectivity if the process is up but messaging still fails

## Release Context

When running from the packaged release:

```bash
app/_build/prod/rel/karyon/bin/karyon start
```

the health endpoints are served by the dashboard endpoint if:

```bash
export KARYON_DASHBOARD_SERVER=true
```

If the dashboard server is disabled, release processes may still be alive while the HTTP health surface is intentionally absent.

---

This book is the operational companion to the architecture and developer material. It remains closer to active project source material than to a polished public operations handbook, but it is still useful as a bounded guide to the constraints and readiness concerns shaping the organism.

Use this book as a bridge into that material while the public docs surface matures.

    Start with the runtime health surfaces and response posture. [Open health](/docs/operations/health/)

    Review the current validated operating envelope and benchmark posture. [Open capacity](/docs/operations/capacity/)

    Use the release workflow and genetic blueprint references when shipping or tuning the organism. [Open releases](/docs/operations/releases/)

## What this book covers today

- Health, readiness, and response runbooks for the current operational surface.
- Capacity, metabolic, and baseline references for the current validated operating envelope.
- Release workflow and DNA authoring guidance for operating and shaping the organism.

---

# Metabolic Operations Playbook

This playbook provides operational guidance for monitoring the health, survival, and performance of the Karyon organism.

## Core Metrics

Monitoring the Metabolic layer requires tracking three primary signals:

### 1. Scheduler Run Queue (`run_queue_wait`)

- **Signal**: The number of processes waiting to execute on the BEAM.
- **Threshold**: Sustained spikes above 10 (per scheduler) trigger `MetabolicDaemon` apoptosis.
- **Action**: If loops occur, check for non-yielding Rustler NIFs or high-frequency synaptic floods.

### 2. L3 Cache Pressure (`cache_constriction`)

- **Signal**: Memory bandwidth utilization monitoring (via `perf` or native NIF proxies).
- **Threshold**: High pressure indicates NUMA traversal penalties.
- **Action**: Verify that `#[repr(align(64))]` is properly applied to new native structs.

### 3. XTDB/Memgraph Starvation (`io_torpor`)

- **Signal**: Transaction submission latency in the `Rhizome.Memory` layer.
- **Threshold**: Latency > 100ms.
- **Action**: Manually trigger `Rhizome.Optimizer` (Sleep Cycle) to prune version-chain bloat or consolidate episodic nodes.

## Apoptosis Debugging

### Cascade Failures

If the `ChaosMonkey` and `MetabolicDaemon` interact poorly, you may see high-frequency "Kill/Spawn" cycles.

- **Detection**: Check `Core.Application` logs for `[EpigeneticSupervisor] Cell Death: :killed`.
- **Mitigation**: Temporarily disable the `ChaosMonkey` to allow the Metabolic layer to stabilize the run queues.

## Dashboard definitions

Use the following Grafana/Prometheus mappings:

- `beam_run_queue_length`: Holistic VM load.
- `rhizome_tx_latency_ms`: Memory health.
- `karyon_apoptosis_total`: Cellular turnover rate.

---

# Karyon Release Workflow

## Build

Build the production-shaped umbrella release from the repository root:

```bash
bin/build_release.sh
```

That script:

- runs `mix deps.get` for the dashboard and umbrella
- builds dashboard static assets with `MIX_ENV=prod`
- builds the umbrella release as `karyon`

Default release output:

```text
app/_build/prod/rel/karyon
```

You can override the output path:

```bash
bin/build_release.sh /tmp/karyon-rel
```

## Required Runtime Environment

Minimum production environment:

```bash
export SECRET_KEY_BASE="$(cd app/dashboard && mix phx.gen.secret)"
export KARYON_DASHBOARD_SERVER=true
```

Common service overrides:

```bash
export KARYON_MEMGRAPH_URL=bolt://memgraph.internal:7687
export KARYON_XTDB_URL=postgres://xtdb.internal:5432/xtdb
export KARYON_NATS_URL=nats://nats.internal:4222
export KARYON_NOCICEPTION_PORT=5555
```

Sandbox/Firecracker host overrides:

```bash
export KARYON_FIRECRACKER_BINARY=/usr/local/bin/firecracker
export KARYON_FIRECRACKER_KERNEL=/opt/karyon/firecracker/vmlinux
export KARYON_FIRECRACKER_ROOTFS=/opt/karyon/firecracker/rootfs.ext4
export KARYON_NET_HELPER=/usr/local/bin/karyon-net-helper
export KARYON_BRIDGE_DEVICE=karyon0
```

Optional safety/runtime flags:

```bash
export KARYON_STRICT_PREFLIGHT=true
export PHX_HOST=karyon.example.com
export PORT=4000
export DNS_CLUSTER_QUERY=karyon.internal
```

## Start

```bash
app/_build/prod/rel/karyon/bin/karyon start
```

Foreground:

```bash
app/_build/prod/rel/karyon/bin/karyon foreground
```

Remote shell:

```bash
app/_build/prod/rel/karyon/bin/karyon remote
```

## Air-Gapped Package

To create the packaged bootstrap artifact:

```bash
cd app
scripts/bootstrap_airgap.sh
```

This now builds the real `karyon` release and archives it into the bootstrap bundle instead of creating a placeholder tarball.
