#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

THEME="${1:-}"

usage() {
  echo "Usage: ./scripts/set-theme.sh aurora|ocean|ember|contrast" >&2
}

if [ -z "$THEME" ]; then
  usage
  exit 1
fi

case "$THEME" in
  aurora)
    theme_name="Aurora"
    release="v1.0"
    accent="#ff4d8d"
    accent_two="#22d3ee"
    accent_three="#facc15"
    headline="Git is the source of truth"
    message="This page is served by nginx, configured by a Kustomize-generated ConfigMap, and deployed by Argo CD."
    metric_a="2 pods"
    metric_b="Manual sync"
    metric_c="Kustomize"
    ;;
  ocean)
    theme_name="Ocean"
    release="v2.0"
    accent="#2dd4bf"
    accent_two="#60a5fa"
    accent_three="#f97316"
    headline="A new commit is waiting to sync"
    message="The Git repository changed first. Argo CD can now show the exact diff before Kubernetes receives it."
    metric_a="2 pods"
    metric_b="OutOfSync"
    metric_c="ConfigMap rollout"
    ;;
  ember)
    theme_name="Ember"
    release="v3.0"
    accent="#fb7185"
    accent_two="#f59e0b"
    accent_three="#38bdf8"
    headline="Sync turns desired state into live state"
    message="Click Sync in Argo CD and refresh this page to show the deployment converging from Git to Kubernetes."
    metric_a="2 pods"
    metric_b="Sync pending"
    metric_c="Rolling update"
    ;;
  contrast)
    theme_name="Contrast"
    release="v4.0"
    accent="#e5e7eb"
    accent_two="#22c55e"
    accent_three="#f43f5e"
    headline="Argo CD repaired the cluster"
    message="Use this version after a self-heal demo to show that the live state is back in line with Git."
    metric_a="Healthy"
    metric_b="Self-heal"
    metric_c="Prune ready"
    ;;
  *)
    usage
    exit 1
    ;;
esac

updated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$PROJECT_ROOT/k8s/color-showcase/site/app-config.js" <<JS
window.DEMO_CONFIG = {
  themeName: "${theme_name}",
  release: "${release}",
  accent: "${accent}",
  accentTwo: "${accent_two}",
  accentThree: "${accent_three}",
  headline: "${headline}",
  message: "${message}",
  metricA: "${metric_a}",
  metricB: "${metric_b}",
  metricC: "${metric_c}",
  updatedAt: "${updated_at}"
};
JS

"$PROJECT_ROOT/scripts/publish-local-git.sh" "Theme ${theme_name}"

