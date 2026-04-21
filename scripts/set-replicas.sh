#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

REPLICAS="${1:-}"

if ! [[ "$REPLICAS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: ./scripts/set-replicas.sh 1|2|3|4..." >&2
  exit 1
fi

sed -i -E "s/replicas: [0-9]+/replicas: ${REPLICAS}/" "$PROJECT_ROOT/k8s/color-showcase/deployment.yaml"
sed -i -E "s/metricA: \"[^\"]+\"/metricA: \"${REPLICAS} pods\"/" "$PROJECT_ROOT/k8s/color-showcase/site/app-config.js"

"$PROJECT_ROOT/scripts/publish-local-git.sh" "Scale demo app to ${REPLICAS} replicas"
