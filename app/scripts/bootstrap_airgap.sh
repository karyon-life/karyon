#!/usr/bin/env bash
set -euo pipefail

# Karyon Air-Gapped Bootstrap Script
# Packages the platform including native binaries, DNA, and internal dependencies.

echo "--- Karyon Air-Gapped Bootstrap ---"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_ROOT/.." && pwd)"
OUTPUT_DIR="$APP_ROOT/release/karyon-bootstrap-$(date +%Y%m%d)"
RELEASE_DIR="$APP_ROOT/_build/prod/rel/karyon"
mkdir -p "$OUTPUT_DIR/bin"
mkdir -p "$OUTPUT_DIR/dna"
mkdir -p "$OUTPUT_DIR/engrams"

echo "1. Consolidating binaries..."
cp bin/karyon-net-helper "$OUTPUT_DIR/bin/"
# In a real environment, we'd add firecracker, protoc, etc.
if [ -d "protoc_bin" ]; then
    cp -r protoc_bin "$OUTPUT_DIR/bin/"
fi

echo "2. Copying genetics (DNA)..."
cp -r "$APP_ROOT/core/priv/dna/"* "$OUTPUT_DIR/dna/"

echo "3. Bundling Mix release..."
"$REPO_ROOT/bin/build_release.sh" "$RELEASE_DIR"
tar -C "$(dirname "$RELEASE_DIR")" -czf "$OUTPUT_DIR/karyon_engine.tar.gz" "$(basename "$RELEASE_DIR")"

echo "4. Creating bootstrap manifest..."
cat <<EOF > "$OUTPUT_DIR/manifest.yml"
version: "0.1.0"
date: "$(date)"
checksums:
  engine: "$(sha256sum "$OUTPUT_DIR/karyon_engine.tar.gz" | awk '{print $1}')"
EOF

echo "--- Production Readiness Package Complete: $OUTPUT_DIR ---"
