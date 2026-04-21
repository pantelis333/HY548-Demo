#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-argocd-demo}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_UI_PORT="${ARGOCD_UI_PORT:-8080}"

if kubectl config get-contexts "k3d-$CLUSTER_NAME" >/dev/null 2>&1; then
  kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null
fi

password="$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"

cat <<TEXT
Argo CD UI:
  https://localhost:${ARGOCD_UI_PORT}
  username: admin
  password: ${password:-not available yet}

Leave this command running while the browser is open.
TEXT

exec kubectl -n "$ARGOCD_NAMESPACE" port-forward svc/argocd-server "${ARGOCD_UI_PORT}:443"

