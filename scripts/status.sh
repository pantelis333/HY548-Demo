#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-argocd-demo}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
APP_NAME="${APP_NAME:-color-showcase}"
APP_NAMESPACE="${APP_NAMESPACE:-color-showcase}"

if kubectl config get-contexts "k3d-$CLUSTER_NAME" >/dev/null 2>&1; then
  kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null
fi

echo "Argo CD application:"
kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" || true

echo
echo "Demo workload:"
kubectl -n "$APP_NAMESPACE" get ingress,svc,deploy,rs,pod || true

