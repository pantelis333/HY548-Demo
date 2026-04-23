#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOCAL_BIN="$PROJECT_ROOT/.demo/bin"
export PATH="$LOCAL_BIN:$PATH"

CLUSTER_NAME="${CLUSTER_NAME:-argocd-demo}"
LOCAL_GIT_CONTAINER="${LOCAL_GIT_CONTAINER:-argocd-demo-git}"
KEEP_DEMO_DATA="${KEEP_DEMO_DATA:-false}"

docker rm -f "$LOCAL_GIT_CONTAINER" >/dev/null 2>&1 || true
k3d cluster delete "$CLUSTER_NAME" >/dev/null 2>&1 || true

if [ "$KEEP_DEMO_DATA" != "true" ]; then
  rm -rf "$PROJECT_ROOT/.demo"
fi

echo "Deleted k3d cluster ${CLUSTER_NAME} and local Git server container."
