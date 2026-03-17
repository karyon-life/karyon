#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UMBRELLA_ROOT="$REPO_ROOT/app"
DASHBOARD_ROOT="$UMBRELLA_ROOT/dashboard"
OUTPUT_DIR="${1:-$UMBRELLA_ROOT/_build/prod/rel/karyon}"

echo "--- Building Karyon release ---"
echo "Repo root: $REPO_ROOT"
echo "Output: $OUTPUT_DIR"

export MIX_ENV=prod
export PROTOC_PATH="${PROTOC_PATH:-$(command -v protoc || true)}"

if [[ -z "${PROTOC_PATH}" && -x "/tmp/protoc/bin/protoc" ]]; then
  export PROTOC_PATH="/tmp/protoc/bin/protoc"
fi

if [[ -z "${PROTOC_PATH}" || ! -x "${PROTOC_PATH}" ]]; then
  echo "protoc is required to build the release. Set PROTOC_PATH or install protoc." >&2
  exit 1
fi

export PATH="$(dirname "$PROTOC_PATH"):$PATH"

pushd "$DASHBOARD_ROOT" >/dev/null
mix deps.get
mix assets.deploy
popd >/dev/null

pushd "$UMBRELLA_ROOT" >/dev/null
mix deps.get
mix release karyon --overwrite --path "$OUTPUT_DIR"
popd >/dev/null

echo "--- Release ready: $OUTPUT_DIR ---"
echo "Start with:"
echo "  SECRET_KEY_BASE=\$(cd \"$DASHBOARD_ROOT\" && mix phx.gen.secret) KARYON_DASHBOARD_SERVER=true \"$OUTPUT_DIR/bin/karyon\" start"
