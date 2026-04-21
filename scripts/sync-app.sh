#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-argocd-demo}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
APP_NAME="${APP_NAME:-color-showcase}"
WAIT_FOR_HEALTH="${WAIT_FOR_HEALTH:-true}"

if kubectl config get-contexts "k3d-$CLUSTER_NAME" >/dev/null 2>&1; then
  kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null
fi

kubectl -n "$ARGOCD_NAMESPACE" patch application "$APP_NAME" --type merge \
  -p '{"operation":{"sync":{"prune":true,"syncOptions":["CreateNamespace=true"]}}}' >/dev/null

echo "Sync requested for ${APP_NAME}."

if [ "$WAIT_FOR_HEALTH" != "true" ]; then
  exit 0
fi

for _ in $(seq 1 90); do
  sync_status="$(kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  health_status="$(kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

  if [ "$sync_status" = "Synced" ] && [ "$health_status" = "Healthy" ]; then
    echo "Application is Synced and Healthy."
    exit 0
  fi

  sleep 5
done

echo "Timed out waiting for ${APP_NAME} to become Synced and Healthy." >&2
kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o wide || true
exit 1

