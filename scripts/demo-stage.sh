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

write_source_config() {
  local stage="$1"
  local headline="$2"
  local message="$3"
  local change="$4"
  local accent="$5"
  local accent_two="$6"
  local mode="$7"
  local steps

  if [ "$mode" = "expanded" ]; then
    steps='[
    { label: "GitHub", value: "HY548-Demo", note: "commit pushed" },
    { label: "Webhook", value: "repo-webhook", note: "2 pods" },
    { label: "Argo CD", value: "compare", note: "desired vs live" },
    { label: "Renderer", value: "commit-renderer", note: "2 pods" },
    { label: "Auditor", value: "sync-auditor", note: "1 pod" }
  ]'
  else
    steps='[
    { label: "GitHub", value: "HY548-Demo", note: "main branch" },
    { label: "Argo CD", value: "source tile", note: "tracks the repo" },
    { label: "Kubernetes", value: "1 pod", note: "baseline state" }
  ]'
  fi

  cat > "$PROJECT_ROOT/k8s/github-source-demo/site/app-config.js" <<JS
window.SOURCE_DEMO_CONFIG = {
  stage: "${stage}",
  headline: "${headline}",
  message: "${message}",
  repo: "github.com/pantelis333/HY548-Demo",
  branch: "main",
  appName: "github-source-demo",
  change: "${change}",
  accent: "${accent}",
  accentTwo: "${accent_two}",
  mode: "${mode}",
  steps: ${steps}
};
JS
}

write_source_kustomization() {
  local mode="$1"
  local extra_resource=""

  if [ "$mode" = "expanded" ]; then
    extra_resource="  - source-flow.yaml"
  fi

  cat > "$PROJECT_ROOT/k8s/github-source-demo/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: github-source-demo

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
${extra_resource}

configMapGenerator:
  - name: github-source-demo-content
    files:
      - site/index.html
      - site/styles.css
      - site/app-config.js
YAML
}

set_color_replicas() {
  sed -i -E "s/replicas: [0-9]+/replicas: $1/" "$PROJECT_ROOT/k8s/color-showcase/deployment.yaml"
}

set_source_replicas() {
  sed -i -E "s/replicas: [0-9]+/replicas: $1/" "$PROJECT_ROOT/k8s/github-source-demo/deployment.yaml"
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

wait_app_rollout() {
  local app="$1"
  local namespace=""
  local deployments=()
  local deployment=""

  if [ "$SYNC" != "true" ]; then
    return 0
  fi

  case "$app" in
    color-showcase)
      namespace="color-showcase"
      deployments=(color-showcase)
      ;;
    guestbook-live)
      namespace="guestbook-live"
      deployments=(guestbook-ui guestbook-api guestbook-cache redis-follower redis-leader)
      ;;
    github-source-demo)
      namespace="github-source-demo"
      deployments=(github-source-demo repo-webhook commit-renderer sync-auditor)
      ;;
    *)
      return 0
      ;;
  esac

  for deployment in "${deployments[@]}"; do
    if kubectl -n "$namespace" get deployment "$deployment" >/dev/null 2>&1; then
      kubectl -n "$namespace" rollout status "deployment/$deployment" --timeout=120s
    fi
  done
}

wait_for_port() {
  local port="$1"

  for _ in $(seq 1 30); do
    if (: >/dev/tcp/127.0.0.1/"$port") >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "Timed out waiting for port ${port}." >&2
  return 1
}

restart_port_forward_if_managed() {
  local app="$1"
  local namespace=""
  local service=""
  local selector=""
  local port=""
  local pid_file=""
  local log_file=""
  local pid=""
  local pod=""

  if [ "$SYNC" != "true" ]; then
    return 0
  fi

  case "$app" in
    color-showcase)
      namespace="color-showcase"
      service="color-showcase"
      selector="app.kubernetes.io/name=color-showcase"
      port="8081"
      pid_file="$PROJECT_ROOT/.demo/color-port-forward.pid"
      log_file="$PROJECT_ROOT/.demo/color-port-forward.log"
      ;;
    guestbook-live)
      namespace="guestbook-live"
      service="guestbook-ui"
      selector="app=guestbook-ui"
      port="8082"
      pid_file="$PROJECT_ROOT/.demo/guestbook-port-forward.pid"
      log_file="$PROJECT_ROOT/.demo/guestbook-port-forward.log"
      ;;
    github-source-demo)
      namespace="github-source-demo"
      service="github-source-demo"
      selector="app.kubernetes.io/name=github-source-demo"
      port="8083"
      pid_file="$PROJECT_ROOT/.demo/github-source-port-forward.pid"
      log_file="$PROJECT_ROOT/.demo/github-source-port-forward.log"
      ;;
    *)
      return 0
      ;;
  esac

  if [ ! -f "$pid_file" ]; then
    return 0
  fi

  pid="$(cat "$pid_file")"
  kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
  rm -f "$pid_file"

  pod="$(kubectl -n "$namespace" get pods -l "$selector" --field-selector=status.phase=Running \
    --sort-by=.metadata.creationTimestamp -o name | tail -n 1 | sed 's#^pod/##')"

  if [ -z "$pod" ]; then
    echo "No running pod found for ${service} in namespace ${namespace}." >&2
    return 1
  fi

  setsid bash -lc "exec kubectl -n ${namespace} port-forward --address 0.0.0.0 pod/${pod} ${port}:80" > "$log_file" 2>&1 &
  echo $! > "$pid_file"
  wait_for_port "$port"
}

publish_and_sync() {
  local message="$1"
  shift
  local apps=("$@")
  local primary_app="${apps[0]:-color-showcase}"

  APP_NAME="$primary_app" "$PROJECT_ROOT/scripts/publish-local-git.sh" "$message"
  for app in "${apps[@]}"; do
    request_refresh "$app"
  done
  for app in "${apps[@]}"; do
    sync_app_if_available "$app"
  done
  for app in "${apps[@]}"; do
    wait_app_rollout "$app"
  done
  for app in "${apps[@]}"; do
    restart_port_forward_if_managed "$app"
  done

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
    set_source_replicas 1
    write_source_kustomization baseline
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
    write_source_config \
      "Stage 0" \
      "HY548-Demo on GitHub" \
      "This third Argo CD application makes the GitHub source visible as its own tile next to color-showcase and guestbook-live." \
      "baseline" \
      "#22d3ee" \
      "#facc15" \
      "baseline"
    publish_and_sync "Stage 0 baseline" color-showcase guestbook-live github-source-demo
    ;;
  demo1)
    set_color_replicas 5
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
    publish_and_sync "Demo 1 color-showcase scale" color-showcase
    ;;
  demo2)
    set_guestbook_ui_replicas 8
    set_named_replicas guestbook-api 3 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas guestbook-cache 3 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/demo-servers.yaml"
    set_named_replicas redis-follower 3 "$PROJECT_ROOT/k8s/guestbook-live-enhanced/redis.yaml"
    publish_and_sync "Demo 2 guestbook topology scale" guestbook-live
    ;;
  demo3)
    set_source_replicas 3
    write_source_kustomization expanded
    write_source_config \
      "Demo 3" \
      "GitHub source flow expanded" \
      "This commit is dedicated to the github-source-demo app. Its Argo CD resource graph grows with webhook, renderer, auditor, services, pods, and a ConfigMap." \
      "source flow expanded" \
      "#e5e7eb" \
      "#22c55e" \
      "expanded"
    publish_and_sync "Demo 3 github-source-demo flow" github-source-demo
    ;;
  *)
    usage
    exit 1
    ;;
esac
