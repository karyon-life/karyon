#!/bin/bash

set -euo pipefail

BRIDGE_NAME="${1:-${KARYON_BRIDGE_NAME:-karyon0}}"
BRIDGE_CIDR="${KARYON_BRIDGE_CIDR:-}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd ip
require_cmd sudo

if [[ "$BRIDGE_NAME" =~ [^a-zA-Z0-9._-] ]]; then
  echo "Invalid bridge name: $BRIDGE_NAME" >&2
  exit 1
fi

bridge_exists() {
  ip link show "$BRIDGE_NAME" >/dev/null 2>&1
}

bridge_has_cidr() {
  local cidr="$1"
  ip -o addr show dev "$BRIDGE_NAME" | grep -Fq " $cidr "
}

echo "Preparing Firecracker bridge: $BRIDGE_NAME"

if bridge_exists; then
  echo "Bridge already exists: $BRIDGE_NAME"
else
  sudo ip link add name "$BRIDGE_NAME" type bridge
  echo "Created bridge: $BRIDGE_NAME"
fi

sudo ip link set "$BRIDGE_NAME" up
sudo ip link set dev "$BRIDGE_NAME" mtu 1500

if [[ -n "$BRIDGE_CIDR" ]]; then
  if bridge_has_cidr "$BRIDGE_CIDR"; then
    echo "Bridge already has CIDR: $BRIDGE_CIDR"
  else
    sudo ip addr add "$BRIDGE_CIDR" dev "$BRIDGE_NAME"
    echo "Assigned CIDR to bridge: $BRIDGE_CIDR"
  fi
fi

echo "--- BRIDGE READY ---"
echo "Bridge: $BRIDGE_NAME"
ip -details link show "$BRIDGE_NAME"

if [[ -n "$BRIDGE_CIDR" ]]; then
  ip -o addr show dev "$BRIDGE_NAME"
fi
