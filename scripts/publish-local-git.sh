#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

CLUSTER_NAME="${CLUSTER_NAME:-argocd-demo}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
APP_NAME="${APP_NAME:-color-showcase}"
TARGET_REVISION="${TARGET_REVISION:-main}"
LOCAL_GIT_CONTAINER="${LOCAL_GIT_CONTAINER:-argocd-demo-git}"
LOCAL_GIT_REPO_NAME="${LOCAL_GIT_REPO_NAME:-argocd-demo.git}"
LOCAL_GIT_DIR="$PROJECT_ROOT/.demo/git"
LOCAL_GIT_REPO="$LOCAL_GIT_DIR/$LOCAL_GIT_REPO_NAME"
COMMIT_MESSAGE="${1:-Update demo source}"

if [ ! -d .git ]; then
  echo "No .git directory found. Run ./scripts/setup.sh first." >&2
  exit 1
fi

if ! git config user.email >/dev/null; then
  git config user.email "argocd-demo@example.local"
fi

if ! git config user.name >/dev/null; then
  git config user.name "Argo CD Demo"
fi

git add -A
if ! git diff --cached --quiet; then
  git commit -m "$COMMIT_MESSAGE" >/dev/null
else
  echo "No local file changes to commit."
fi

mkdir -p "$LOCAL_GIT_DIR"
if [ ! -d "$LOCAL_GIT_REPO" ]; then
  git init --bare "$LOCAL_GIT_REPO" >/dev/null
fi

git --git-dir="$LOCAL_GIT_REPO" symbolic-ref HEAD "refs/heads/$TARGET_REVISION"
git push --force "$LOCAL_GIT_REPO" "HEAD:refs/heads/$TARGET_REVISION" >/dev/null
git --git-dir="$LOCAL_GIT_REPO" update-server-info

if ! docker ps --format '{{.Names}}' | grep -qx "$LOCAL_GIT_CONTAINER"; then
  echo "Local Git server container is not running. Run ./scripts/setup.sh to recreate it." >&2
fi

if kubectl config get-contexts "k3d-$CLUSTER_NAME" >/dev/null 2>&1; then
  kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null
fi

if kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" >/dev/null 2>&1; then
  kubectl -n "$ARGOCD_NAMESPACE" annotate application "$APP_NAME" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  echo "Published local Git repo and requested an Argo CD hard refresh."
  echo "Open Argo CD to review the diff, then run ./scripts/sync-app.sh or click Sync in the UI."
else
  echo "Published local Git repo. Argo CD application was not found yet."
fi
