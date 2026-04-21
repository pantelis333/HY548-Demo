#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-argocd-demo}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
APP_NAME="${APP_NAME:-guestbook-live}"

if kubectl config get-contexts "k3d-$CLUSTER_NAME" >/dev/null 2>&1; then
  kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -x "$PROJECT_ROOT/scripts/publish-local-git.sh" ]; then
  "$PROJECT_ROOT/scripts/publish-local-git.sh" "Update guestbook live demo" >/dev/null
fi

kubectl apply -f "$PROJECT_ROOT/argocd/applications/guestbook-live.yaml"

kubectl -n "$ARGOCD_NAMESPACE" annotate application "$APP_NAME" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
kubectl -n "$ARGOCD_NAMESPACE" patch application "$APP_NAME" --type merge \
  -p '{"operation":{"sync":{"prune":true,"syncOptions":["CreateNamespace=true"]}}}' >/dev/null

echo "Sync requested for ${APP_NAME}. The local Kustomize overlay pulls upstream guestbook YAML from GitHub."

for _ in $(seq 1 90); do
  sync_status="$(kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  health_status="$(kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

  if [ "$sync_status" = "Synced" ] && [ "$health_status" = "Healthy" ]; then
    echo "Application ${APP_NAME} is Synced and Healthy."
    kubectl -n guestbook-live get deploy,svc,pod
    exit 0
  fi

  sleep 5
done

echo "Timed out waiting for ${APP_NAME} to become Synced and Healthy." >&2
kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o wide || true
exit 1
