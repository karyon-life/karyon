# Firecracker Membrane Contract

This document captures the resolved Chapter 3 Section 5 membrane contract for the sandbox boundary.

## Storage Contract

- The guest root filesystem is immutable and attached as a read-only `virtio-blk` device.
- Every microVM receives its own writable `virtio-blk` workspace image.
- The host stages workspace metadata and manifests under `~/.karyon/sandboxes/<vm_id>/`.
- The guest-facing writable workspace is mounted at `/mnt/workspace`.

## Overlay Policy

- The host-side membrane root contains a `workspace/` staging directory, an `overlay/` directory, and a writable `workspace.ext4` disk image.
- Execution manifests are written before boot so every VM has an explicit plan-to-workspace bridge contract.
- Teardown removes the entire per-VM membrane root after the VMM stops.

## Governance Resolution

- `virtio-fs` assumptions are retired from the sandbox boundary.
- The implementation standard is `virtio-blk` plus overlay-backed writable workspaces, matching current repository governance in [`AGENTS.md`](/home/adrian/Projects/nexical/karyon/AGENTS.md).
