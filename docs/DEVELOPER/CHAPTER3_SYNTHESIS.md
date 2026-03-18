# Chapter 3 Synthesis

This document captures the Chapter 3 wrap-up gate for the physical organism layers defined in:

- `docs/src/content/docs/part-2/chapter-3/1-introduction.md`
- `docs/src/content/docs/part-2/chapter-3/2-microkernel-philosophy.md`
- `docs/src/content/docs/part-2/chapter-3/3-erlang-beam-cytoplasm.md`
- `docs/src/content/docs/part-2/chapter-3/4-rust-nifs-organelles.md`
- `docs/src/content/docs/part-2/chapter-3/5-the-kvm-qemu-membrane.md`
- `docs/src/content/docs/part-2/chapter-3/6-the-nervous-system.md`
- `docs/src/content/docs/part-2/chapter-3/7-chapter-wrap-up.md`

Chapter 3 synthesis requires these behaviors:

- Subsystem ownership remains isolated across `core`, `sandbox`, `nervous_system`, and `rhizome`.
- The sterile core keeps declarative executor boundaries and validated cytoplasm behavior.
- The sandbox enforces the resolved `virtio-blk` plus overlay-backed membrane contract.
- The nervous system preserves the ZeroMQ peer plane and NATS global control plane split.
- Rhizome organelle boundaries remain explicit, scheduled correctly, and panic-safe.

Local command:

```bash
cd /home/adrian/Projects/nexical/karyon/app && mix chapter3.synthesis
```

This suite is expected to fail when:

- Firecracker embodiment logic leaks back into the sterile core.
- The sandbox loses its immutable-rootfs plus writable-workspace membrane contract.
- Synapse and Endocrine transports collapse into an untyped or untelemetried signaling layer.
- Rhizome native boundaries lose their scheduler or panic-containment guarantees.

The GitHub Actions workflow `chapter3-synthesis.yml` must pass on pushes and pull requests that touch the repository.
