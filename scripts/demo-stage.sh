#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

STAGE="${1:-}"
SYNC="${SYNC:-true}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

usage() {
  echo "Usage: ./scripts/demo-stage.sh stage0|demo1|demo2|demo3" >&2
}

write_color_config() {
  local theme_name="$1"
  local release="$2"
  local accent="$3"
  local accent_two="$4"
  local accent_three="$5"
  local headline="$6"
  local message="$7"
  local metric_a="$8"
  local metric_b="$9"
  local metric_c="${10}"
  local updated_at="${11}"

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
}

set_color_replicas() {
  sed -i -E "s/replicas: [0-9]+/replicas: $1/" "$PROJECT_ROOT/k8s/color-showcase/deployment.yaml"
}

set_guestbook_ui_replicas() {
  perl -0pi -e 's/(path: \/spec\/replicas\s+value: )\d+/${1}'"$1"'/s' \
    "$PROJECT_ROOT/k8s/guestbook-live-enhanced/kustomization.yaml"
}

set_named_replicas() {
  local name="$1"
  local replicas="$2"
  local file="$3"

  sed -i '/name: '"$name"'/,/selector:/ s/replicas: [0-9]\+/replicas: '"$replicas"'/' "$file"
}

request_refresh() {
  local app="$1"

  kubectl -n "$ARGOCD_NAMESPACE" annotate application "$app" \
    argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
}

sync_app_if_available() {
  local app="$1"

  if [ "$SYNC" != "true" ]; then
    return 0
  fi

  if kubectl -n "$ARGOCD_NAMESPACE" get application "$app" >/dev/null 2>&1; then
    APP_NAME="$app" "$PROJECT_ROOT/scripts/sync-app.sh"
  fi
}

publish_and_sync() {
  local message="$1"

  APP_NAME=color-showcase "$PROJECT_ROOT/scripts/publish-local-git.sh" "$message"
  request_refresh color-showcase
  request_refresh guestbook-live
  sync_app_if_available color-showcase
  sync_app_if_available guestbook-live

  echo
  echo "GitHub commit: $(git rev-parse --short HEAD) ${message}"
  echo "Repo: https://github.com/pantelis333/HY548-Demo/tree/main"
}

if [ -z "$STAGE" ]; then
  usage
  exit 1
fi

case "$STAGE" in
  stage0)
    set_color_replicas 2
    set_guestbook_ui_replicas 2
    set_named_replicas guestbook-api 1 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas guestbook-cache 1 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas redis-follower 1 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/redis.yaml"
    write_color_config \
      "Stage 0" \
      "baseline" \
      "#ff4d8d" \
      "#22d3ee" \
      "#facc15" \
      "Stage 0: Git is the source of truth" \
      "The cluster is synced to the GitHub repository. This is the clean starting point before the demo changes begin." \
      "2 color pods" \
      "2 guestbook UI" \
      "GitHub main" \
      "stage0"
    publish_and_sync "Stage 0 baseline"
    ;;
  demo1)
    set_color_replicas 5
    set_guestbook_ui_replicas 2
    set_named_replicas guestbook-api 1 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas guestbook-cache 1 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas redis-follower 1 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/redis.yaml"
    write_color_config \
      "Demo 1" \
      "scale-up" \
      "#2dd4bf" \
      "#60a5fa" \
      "#f97316" \
      "Demo 1: a Git commit scaled the app" \
      "The desired replica count changed in GitHub. Argo CD synced the commit and Kubernetes created more color-showcase pods." \
      "5 color pods" \
      "Argo synced" \
      "Replica rollout" \
      "demo1"
    publish_and_sync "Demo 1 scale color-showcase"
    ;;
  demo2)
    set_color_replicas 3
    set_guestbook_ui_replicas 8
    set_named_replicas guestbook-api 3 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas guestbook-cache 3 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas redis-follower 3 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/redis.yaml"
    write_color_config \
      "Demo 2" \
      "guestbook" \
      "#a78bfa" \
      "#34d399" \
      "#fbbf24" \
      "Demo 2: the guestbook topology grew" \
      "One commit changed several Kubernetes deployments. The guestbook tree now has more UI, API, cache, and Redis follower pods." \
      "8 UI pods" \
      "3 API + 3 cache" \
      "3 Redis followers" \
      "demo2"
    publish_and_sync "Demo 2 scale guestbook topology"
    ;;
  demo3)
    set_color_replicas 4
    set_guestbook_ui_replicas 6
    set_named_replicas guestbook-api 2 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas guestbook-cache 2 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas redis-follower 2 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/redis.yaml"
    write_color_config \
      "Demo 3" \
      "release" \
      "#e5e7eb" \
      "#22c55e" \
      "#f43f5e" \
      "Demo 3: the release commit is live" \
      "This final GitHub commit is a ready-to-present release state: a visible UI change, a new revision in Argo CD, and balanced pod counts." \
      "4 color pods" \
      "6 guestbook UI" \
      "Release commit" \
      "demo3"
    publish_and_sync "Demo 3 release-ready state"
    ;;
  *)
    usage
    exit 1
    ;;
esac
