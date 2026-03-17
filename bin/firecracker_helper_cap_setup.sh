#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_HELPER_PATH="$REPO_ROOT/app/sandbox/native/net_helper/target/release/net_helper"
DEFAULT_INSTALL_PATH="/usr/local/bin/karyon-net-helper"
INSTALL_SYSTEM=0
HELPER_PATH="${KARYON_NET_HELPER:-$DEFAULT_HELPER_PATH}"

usage() {
  cat <<'EOF'
Usage:
  bin/firecracker_helper_cap_setup.sh [helper_path]
  bin/firecracker_helper_cap_setup.sh --install-system [helper_path] [install_path]

Modes:
  default
    Attempts to apply CAP_NET_ADMIN to the helper in place.

  --install-system
    Copies the helper to a capability-friendly path, then applies CAP_NET_ADMIN.
    Default install path: /usr/local/bin/karyon-net-helper
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-system)
      INSTALL_SYSTEM=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "$HELPER_PATH" == "${KARYON_NET_HELPER:-$DEFAULT_HELPER_PATH}" ]]; then
        HELPER_PATH="$1"
      else
        DEFAULT_INSTALL_PATH="$1"
      fi
      shift
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd sudo
require_cmd setcap
require_cmd getcap

if [[ ! -f "$HELPER_PATH" ]]; then
  echo "Helper binary not found: $HELPER_PATH" >&2
  exit 1
fi

if [[ ! -x "$HELPER_PATH" ]]; then
  echo "Helper binary is not executable: $HELPER_PATH" >&2
  exit 1
fi

print_fallback_instructions() {
  local helper_path="$1"
  local install_path="$2"

  cat <<EOF
Failed to apply capabilities in place. This usually means the current filesystem
does not support file capabilities for this path.

Recommended fallback:
  1. Copy the helper into a capability-friendly system path:
     sudo cp "$helper_path" "$install_path"
     sudo chmod 755 "$install_path"

  2. Apply CAP_NET_ADMIN there:
     sudo setcap cap_net_admin+ep "$install_path"
     getcap "$install_path"

  3. Point Karyon at the installed helper:
     export KARYON_NET_HELPER="$install_path"
EOF
}

apply_capability() {
  local path="$1"
  echo "Granting CAP_NET_ADMIN to helper:"
  echo "  $path"

  if sudo setcap cap_net_admin+ep "$path"; then
    echo "--- CAPABILITY STATUS ---"
    getcap "$path"
    return 0
  fi

  return 1
}

install_helper() {
  local source_path="$1"
  local install_path="$2"

  echo "Installing helper to:"
  echo "  $install_path"
  sudo cp "$source_path" "$install_path"
  sudo chmod 755 "$install_path"
}

auto_fallback_install() {
  local source_path="$1"
  local install_path="$2"

  echo
  echo "In-place capability setup failed. Attempting automatic fallback install..."
  install_helper "$source_path" "$install_path"

  if apply_capability "$install_path"; then
    echo
    echo "Export this for Karyon:"
    echo "  export KARYON_NET_HELPER=$install_path"
    return 0
  fi

  return 1
}

if [[ "$INSTALL_SYSTEM" -eq 1 ]]; then
  install_helper "$HELPER_PATH" "$DEFAULT_INSTALL_PATH"
  apply_capability "$DEFAULT_INSTALL_PATH"
  echo
  echo "Export this for Karyon:"
  echo "  export KARYON_NET_HELPER=$DEFAULT_INSTALL_PATH"
  exit 0
fi

if ! apply_capability "$HELPER_PATH"; then
  if ! auto_fallback_install "$HELPER_PATH" "$DEFAULT_INSTALL_PATH"; then
    echo
    print_fallback_instructions "$HELPER_PATH" "$DEFAULT_INSTALL_PATH"
    exit 1
  fi
fi
