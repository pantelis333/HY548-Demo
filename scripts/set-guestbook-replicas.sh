#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

COMPONENT="${1:-}"
REPLICAS="${2:-}"

usage() {
  echo "Usage: ./scripts/set-guestbook-replicas.sh ui|api|cache|redis-follower <replicas>" >&2
}

if [ -z "$COMPONENT" ] || [ -z "$REPLICAS" ]; then
  usage
  exit 1
fi

if ! [[ "$REPLICAS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Replica count must be a positive integer." >&2
  exit 1
fi

case "$COMPONENT" in
  ui)
    perl -0pi -e 's/(path: \/spec\/replicas\s+value: )\d+/${1}'"$REPLICAS"'/s' \
      "$PROJECT_ROOT/k8s/guestbook-live-enhanced/kustomization.yaml"
    ;;
  api)
    sed -i '/name: guestbook-api/,/selector:/ s/replicas: [0-9]\+/replicas: '"$REPLICAS"'/' \
      "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    ;;
  cache)
    sed -i '/name: guestbook-cache/,/selector:/ s/replicas: [0-9]\+/replicas: '"$REPLICAS"'/' \
      "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    ;;
  redis-follower)
    sed -i '/name: redis-follower/,/selector:/ s/replicas: [0-9]\+/replicas: '"$REPLICAS"'/' \
      "$PROJECT_ROOT/k8s/guestbook-live-enhanced/redis.yaml"
    ;;
  *)
    usage
    exit 1
    ;;
esac

APP_NAME=guestbook-live "$PROJECT_ROOT/scripts/publish-local-git.sh" \
  "Scale guestbook ${COMPONENT} to ${REPLICAS} replicas"
