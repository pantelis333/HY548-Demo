#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

CLUSTER_NAME="${CLUSTER_NAME:-argocd-demo}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
TARGET_REVISION="${TARGET_REVISION:-main}"
REPO_URL_INPUT="${1:-${REPO_URL:-}}"

usage() {
  echo "Usage: ./scripts/use-repo.sh <repo-url>" >&2
}

if [ -z "$REPO_URL_INPUT" ]; then
  usage
  exit 1
fi

if kubectl config get-contexts "k3d-$CLUSTER_NAME" >/dev/null 2>&1; then
  kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null
fi

normalize_repo_url_for_argocd() {
  case "$1" in
    git@github.com:*)
      printf 'https://github.com/%s\n' "${1#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      printf 'https://github.com/%s\n' "${1#ssh://git@github.com/}"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

apply_template() {
  local template_file="$1"
  local repo_url="$2"
  local escaped_repo_url
  local escaped_revision

  escaped_repo_url="$(escape_sed_replacement "$repo_url")"
  escaped_revision="$(escape_sed_replacement "$TARGET_REVISION")"

  sed \
    -e "s|__REPO_URL__|${escaped_repo_url}|g" \
    -e "s|__TARGET_REVISION__|${escaped_revision}|g" \
    "$template_file" | kubectl apply -f - >/dev/null
}

ARGO_REPO_URL="$(normalize_repo_url_for_argocd "$REPO_URL_INPUT")"

apply_template "$PROJECT_ROOT/argocd/applications/color-showcase.template.yaml" "$ARGO_REPO_URL"
apply_template "$PROJECT_ROOT/argocd/applications/guestbook-live.template.yaml" "$ARGO_REPO_URL"

kubectl -n "$ARGOCD_NAMESPACE" annotate application color-showcase argocd.argoproj.io/refresh=hard --overwrite >/dev/null
kubectl -n "$ARGOCD_NAMESPACE" annotate application guestbook-live argocd.argoproj.io/refresh=hard --overwrite >/dev/null

echo "Updated Argo CD applications to use:"
echo "  ${ARGO_REPO_URL}"
echo "Target revision:"
echo "  ${TARGET_REVISION}"
