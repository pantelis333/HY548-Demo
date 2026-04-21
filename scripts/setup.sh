#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOCAL_BIN="$PROJECT_ROOT/.demo/bin"
mkdir -p "$LOCAL_BIN"
export PATH="$LOCAL_BIN:$PATH"

CLUSTER_NAME="${CLUSTER_NAME:-argocd-demo}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
APP_NAME="${APP_NAME:-color-showcase}"
HOST_APP_PORT="${HOST_APP_PORT:-8081}"
KUBE_API_PORT="${KUBE_API_PORT:-6550}"
TARGET_REVISION="${TARGET_REVISION:-main}"
RUN_INITIAL_SYNC="${RUN_INITIAL_SYNC:-true}"
ARGOCD_INSTALL_URL="${ARGOCD_INSTALL_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"
LOCAL_GIT_CONTAINER="${LOCAL_GIT_CONTAINER:-argocd-demo-git}"
LOCAL_GIT_REPO_NAME="${LOCAL_GIT_REPO_NAME:-argocd-demo.git}"
LOCAL_GIT_IMAGE="${LOCAL_GIT_IMAGE:-alpine/git:latest}"
LOCAL_GIT_DIR="$PROJECT_ROOT/.demo/git"
LOCAL_GIT_REPO="$LOCAL_GIT_DIR/$LOCAL_GIT_REPO_NAME"

require_commands() {
  local missing=()
  for command_name in docker kubectl git curl; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      missing+=("$command_name")
    fi
  done

  if ((${#missing[@]} > 0)); then
    echo "Missing required commands: ${missing[*]}" >&2
    echo "Install Docker, kubectl, git, and curl, then run this script again." >&2
    exit 1
  fi
}

ensure_k3d() {
  if command -v k3d >/dev/null 2>&1; then
    return 0
  fi

  local os
  local arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    linux) os="linux" ;;
    darwin) os="darwin" ;;
    *)
      echo "Automatic k3d install is not supported for OS: $os" >&2
      echo "Install k3d manually from https://k3d.io/ and run this script again." >&2
      exit 1
      ;;
  esac

  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "Automatic k3d install is not supported for architecture: $arch" >&2
      echo "Install k3d manually from https://k3d.io/ and run this script again." >&2
      exit 1
      ;;
  esac

  echo "k3d was not found. Downloading k3d into .demo/bin."
  curl -fsSL -o "$LOCAL_BIN/k3d" "https://github.com/k3d-io/k3d/releases/latest/download/k3d-${os}-${arch}"
  chmod +x "$LOCAL_BIN/k3d"
}

is_user_listed_in_docker_group() {
  getent group docker 2>/dev/null | awk -F: '{print "," $4 ","}' | grep -q ",${USER},"
}

reexec_with_docker_group() {
  if ! command -v sg >/dev/null 2>&1; then
    return 1
  fi

  if [ "${ARGOCD_DEMO_IN_DOCKER_GROUP:-false}" = "true" ]; then
    return 1
  fi

  if ! is_user_listed_in_docker_group; then
    return 1
  fi

  echo "Docker access is available through the docker group, but this terminal has not picked it up yet."
  echo "Re-running setup inside a fresh docker-group shell."

  local env_command
  env_command="cd $(printf '%q' "$PROJECT_ROOT") && PATH=$(printf '%q' "$PATH") ARGOCD_DEMO_IN_DOCKER_GROUP=true"

  local var_name
  for var_name in \
    CLUSTER_NAME ARGOCD_NAMESPACE APP_NAME HOST_APP_PORT KUBE_API_PORT TARGET_REVISION \
    RUN_INITIAL_SYNC ARGOCD_INSTALL_URL LOCAL_GIT_CONTAINER LOCAL_GIT_REPO_NAME LOCAL_GIT_IMAGE REPO_URL; do
    if [ -n "${!var_name+x}" ]; then
      env_command+=" $(printf '%q' "${var_name}=${!var_name}")"
    fi
  done

  env_command+=" bash $(printf '%q' "$PROJECT_ROOT/scripts/setup.sh")"
  exec sg docker -c "$env_command"
}

ensure_docker_access() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi

  reexec_with_docker_group || {
    echo "Docker is not running or the current user cannot access it." >&2
    echo "If the error is permission denied, run ./scripts/fix-docker-permissions.sh, then reopen the terminal." >&2
    exit 1
  }
}

ensure_git_repo() {
  if [ ! -d .git ]; then
    echo "Initializing a local Git repository for the demo."
    git init -b "$TARGET_REVISION" >/dev/null 2>&1 || {
      git init >/dev/null
      git checkout -B "$TARGET_REVISION" >/dev/null
    }
  fi

  if ! git config user.email >/dev/null; then
    git config user.email "argocd-demo@example.local"
  fi

  if ! git config user.name >/dev/null; then
    git config user.name "Argo CD Demo"
  fi

  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Update Argo CD demo source" >/dev/null
  elif ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    git commit --allow-empty -m "Initialize Argo CD demo source" >/dev/null
  fi
}

publish_local_git_repo() {
  mkdir -p "$LOCAL_GIT_DIR"

  if [ ! -d "$LOCAL_GIT_REPO" ]; then
    git init --bare "$LOCAL_GIT_REPO" >/dev/null
  fi

  git --git-dir="$LOCAL_GIT_REPO" symbolic-ref HEAD "refs/heads/$TARGET_REVISION"
  git push --force "$LOCAL_GIT_REPO" "HEAD:refs/heads/$TARGET_REVISION" >/dev/null
  git --git-dir="$LOCAL_GIT_REPO" update-server-info
}

create_cluster() {
  if k3d cluster list "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "Using existing k3d cluster: $CLUSTER_NAME"
  else
    echo "Creating k3d cluster: $CLUSTER_NAME"
    k3d cluster create "$CLUSTER_NAME" \
      --api-port "$KUBE_API_PORT" \
      -p "${HOST_APP_PORT}:80@loadbalancer" \
      --agents 1 \
      --wait
  fi

  kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null
}

start_local_git_server() {
  docker rm -f "$LOCAL_GIT_CONTAINER" >/dev/null 2>&1 || true
  docker run -d \
    --name "$LOCAL_GIT_CONTAINER" \
    --network "k3d-$CLUSTER_NAME" \
    -v "$LOCAL_GIT_DIR:/git:ro" \
    "$LOCAL_GIT_IMAGE" \
    daemon --verbose --export-all --base-path=/git --reuseaddr /git >/dev/null

  local git_ip
  git_ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$LOCAL_GIT_CONTAINER")"

  kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Service
metadata:
  name: demo-git
  namespace: ${ARGOCD_NAMESPACE}
spec:
  ports:
    - name: git
      port: 9418
      targetPort: 9418
---
apiVersion: v1
kind: Endpoints
metadata:
  name: demo-git
  namespace: ${ARGOCD_NAMESPACE}
subsets:
  - addresses:
      - ip: ${git_ip}
    ports:
      - name: git
        port: 9418
YAML
}

install_argocd() {
  kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  echo "Installing Argo CD from: $ARGOCD_INSTALL_URL"
  kubectl apply -n "$ARGOCD_NAMESPACE" --server-side --force-conflicts -f "$ARGOCD_INSTALL_URL" >/dev/null
  kubectl -n "$ARGOCD_NAMESPACE" wait --for=condition=Available deployment --all --timeout=420s
  kubectl -n "$ARGOCD_NAMESPACE" rollout status statefulset/argocd-application-controller --timeout=420s
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

apply_argocd_application() {
  local repo_url="${REPO_URL:-git://demo-git.${ARGOCD_NAMESPACE}.svc.cluster.local/${LOCAL_GIT_REPO_NAME}}"
  local escaped_repo_url
  local escaped_revision
  escaped_repo_url="$(escape_sed_replacement "$repo_url")"
  escaped_revision="$(escape_sed_replacement "$TARGET_REVISION")"

  sed \
    -e "s|__REPO_URL__|${escaped_repo_url}|g" \
    -e "s|__TARGET_REVISION__|${escaped_revision}|g" \
    "$PROJECT_ROOT/argocd/applications/color-showcase.template.yaml" | kubectl apply -f -
}

sync_application() {
  kubectl -n "$ARGOCD_NAMESPACE" patch application "$APP_NAME" --type merge \
    -p '{"operation":{"sync":{"prune":true,"syncOptions":["CreateNamespace=true"]}}}' >/dev/null
}

wait_for_application() {
  local sync_status=""
  local health_status=""

  for _ in $(seq 1 90); do
    sync_status="$(kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

    if [ "$sync_status" = "Synced" ] && [ "$health_status" = "Healthy" ]; then
      echo "Application is Synced and Healthy."
      return 0
    fi

    sleep 5
  done

  echo "Application did not become Synced and Healthy within the timeout." >&2
  kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o wide || true
  return 1
}

print_access_details() {
  local password
  password="$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"

  cat <<TEXT

Setup complete.

Argo CD UI:
  ./scripts/argocd-port-forward.sh
  https://localhost:8080
  username: admin
  password: ${password:-run ./scripts/argocd-port-forward.sh to print it}

Demo app:
  http://localhost:${HOST_APP_PORT}

Useful next commands:
  ./scripts/set-theme.sh ocean
  ./scripts/sync-app.sh
  ./scripts/set-replicas.sh 4
TEXT
}

main() {
  require_commands
  ensure_k3d
  ensure_docker_access

  if [ -z "${REPO_URL:-}" ]; then
    ensure_git_repo
    publish_local_git_repo
  else
    echo "Using external Git repository: $REPO_URL"
  fi

  create_cluster

  if [ -z "${REPO_URL:-}" ]; then
    start_local_git_server
  fi

  install_argocd
  apply_argocd_application

  if [ "$RUN_INITIAL_SYNC" = "true" ]; then
    sync_application
    wait_for_application
  else
    echo "Initial sync skipped. Open Argo CD and sync the color-showcase app manually."
  fi

  print_access_details
}

main "$@"
