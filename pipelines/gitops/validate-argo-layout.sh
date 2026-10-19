#!/usr/bin/env bash
# Static preflight for the exact Argo CD source layout in this repository.
# It has no kubeconfig, cloud, registry, Git provider or Argo API use.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
delivery_root="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"
repository_root="$(git -C "${delivery_root}" rev-parse --show-toplevel)"
argo_root="${delivery_root}/argoCD/argo"

require_file() {
  test -f "$1" || { echo "missing required file: $1" >&2; exit 1; }
}

require_text() {
  grep -Fq "$2" "$1" || { echo "missing required configuration in $1: $2" >&2; exit 1; }
}

require_absent() {
  ! grep -Fq "$2" "$1" || { echo "forbidden configuration in $1: $2" >&2; exit 1; }
}

for file in \
  "${argo_root}/bootstrap/argocd-bootstrap.yaml" \
  "${argo_root}/bootstrap/argocd-bootstrap-azure-staging.yaml" \
  "${argo_root}/bootstrap/argocd-bootstrap-azure-prod.yaml" \
  "${argo_root}/applications/services-dev/applicationset.yaml" \
  "${argo_root}/applications/services-staging/applicationset.yaml" \
  "${argo_root}/applications/services-prod/applicationset.yaml" \
  "${argo_root}/applications/platform-staging/application.yaml" \
  "${argo_root}/applications/platform-prod/application.yaml" \
  "${argo_root}/projects/cluster-addons/project.yaml" \
  "${argo_root}/namespaces/local/namespace.yaml" \
  "${argo_root}/namespaces/azure-staging/namespace.yaml" \
  "${argo_root}/namespaces/azure-prod/namespace.yaml" \
  "${argo_root}/config/argocd-cm-health.yaml"; do
  require_file "$file"
done

# These are paths from the Git repository root.
for path in \
  argoCD/argo/overlays/local \
  argoCD/argo/overlays/azure-staging \
  argoCD/argo/overlays/azure-prod \
  argoCD/helm/cluster-addons \
  argoCD/helm/services/config-ingestor \
  argoCD/helm/services/gateway-ingestor; do
  test -d "${repository_root}/${path}" || { echo "Argo Git path does not exist: ${path}" >&2; exit 1; }
done

require_text "${argo_root}/bootstrap/argocd-bootstrap.yaml" "path: argoCD/argo/overlays/local"
require_text "${argo_root}/bootstrap/argocd-bootstrap-azure-staging.yaml" "path: argoCD/argo/overlays/azure-staging"
require_text "${argo_root}/bootstrap/argocd-bootstrap-azure-prod.yaml" "path: argoCD/argo/overlays/azure-prod"
require_text "${argo_root}/applications/services-dev/applicationset.yaml" "path: argoCD/helm/services/*"
require_text "${argo_root}/applications/services-dev/applicationset.yaml" "values-local.yaml"
require_text "${argo_root}/applications/services-staging/applicationset.yaml" "values-azure.yaml"
require_text "${argo_root}/applications/services-prod/applicationset.yaml" "values-prod.yaml"
require_absent "${argo_root}/applications/services-dev/applicationset.yaml" "CreateNamespace=true"
require_absent "${argo_root}/applications/services-staging/applicationset.yaml" "CreateNamespace=true"
require_absent "${argo_root}/applications/services-prod/applicationset.yaml" "CreateNamespace=true"
require_text "${argo_root}/overlays/local/kustomization.yaml" "../../namespaces/local"
require_text "${argo_root}/overlays/azure-staging/kustomization.yaml" "../../namespaces/azure-staging"
require_text "${argo_root}/overlays/azure-prod/kustomization.yaml" "../../namespaces/azure-prod"
require_text "${argo_root}/namespaces/local/namespace.yaml" "name: spaceup-dev"
require_text "${argo_root}/namespaces/azure-staging/namespace.yaml" "name: spaceup-staging"
require_text "${argo_root}/namespaces/azure-prod/namespace.yaml" "name: spaceup"
require_text "${argo_root}/applications/platform-prod/application.yaml" "path: argoCD/helm/cluster-addons"
require_text "${argo_root}/projects/cluster-addons/project.yaml" "namespace: external-secrets"
require_text "${argo_root}/config/argocd-cm-health.yaml" "argocd.argoproj.io/sync-wave: \"-40\""
require_text "${argo_root}/config/argocd-cm-health.yaml" "resource.customizations.health.argoproj.io_Application"

render() {
  local release="$1"
  local chart="$2"
  local namespace="$3"
  shift 3
  helm lint "$chart" "$@"
  helm template "$release" "$chart" --namespace "$namespace" "$@" >/dev/null
}

render config-ingestor "${delivery_root}/argoCD/helm/services/config-ingestor" spaceup-dev \
  -f "${delivery_root}/argoCD/helm/services/config-ingestor/values.yaml" \
  -f "${delivery_root}/argoCD/helm/services/config-ingestor/values-dev.yaml" \
  -f "${delivery_root}/argoCD/helm/services/config-ingestor/values-local.yaml"
render gateway-ingestor "${delivery_root}/argoCD/helm/services/gateway-ingestor" spaceup-dev \
  -f "${delivery_root}/argoCD/helm/services/gateway-ingestor/values.yaml" \
  -f "${delivery_root}/argoCD/helm/services/gateway-ingestor/values-dev.yaml" \
  -f "${delivery_root}/argoCD/helm/services/gateway-ingestor/values-local.yaml"
render cluster-addons-staging "${delivery_root}/argoCD/helm/cluster-addons" platform-system \
  -f "${delivery_root}/argoCD/helm/cluster-addons/values.yaml" \
  -f "${delivery_root}/argoCD/helm/cluster-addons/values-azure.yaml" \
  -f "${delivery_root}/argoCD/helm/cluster-addons/values-staging.yaml"
render cluster-addons-prod "${delivery_root}/argoCD/helm/cluster-addons" platform-system \
  -f "${delivery_root}/argoCD/helm/cluster-addons/values.yaml" \
  -f "${delivery_root}/argoCD/helm/cluster-addons/values-azure.yaml" \
  -f "${delivery_root}/argoCD/helm/cluster-addons/values-prod.yaml"

echo "Argo CD source layout and active Helm render preflight passed."
