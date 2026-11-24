#!/usr/bin/env bash
# Offline structural preflight: no cluster, cloud, registry or Git API access.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"
argo="${root}/argoCD/argo"

need_dir() { test -d "$1" || { echo "missing directory: $1" >&2; exit 1; }; }
need_file() { test -f "$1" || { echo "missing file: $1" >&2; exit 1; }; }
must_contain() { grep -Fq "$2" "$1" || { echo "missing '$2' in $1" >&2; exit 1; }; }
must_not_contain() { ! grep -Fq "$2" "$1" || { echo "forbidden '$2' in $1" >&2; exit 1; }; }
render() { helm lint "$2" "${@:4}" && helm template "$1" "$2" --namespace "$3" "${@:4}" >/dev/null; }

cert="${root}/argoCD/helm/foundation/networking/cert-manager"
external_secrets="${root}/argoCD/helm/foundation/security/external-secrets"
policy_engine="${root}/argoCD/helm/foundation/security/policy-engine"
monitoring="${root}/argoCD/helm/platform/observability/monitoring"
consul="${root}/argoCD/helm/platform/runtime/consul"
kafka="${root}/argoCD/helm/platform/eventing/kafka"
keycloak="${root}/argoCD/helm/platform/identity/keycloak"
config="${root}/argoCD/helm/services/configuration/config-server"
gateway="${root}/argoCD/helm/services/networking/api-gateway"
workload_contract="${root}/argoCD/contracts/MICROSERVICE-DEPLOYMENT-CONTRACT.md"

for chart in "$cert" "$external_secrets" "$policy_engine" "$monitoring" "$consul" "$kafka" "$keycloak" "$config" "$gateway"; do need_dir "$chart"; done
need_file "$workload_contract"
test ! -d "${root}/argoCD/helm/cluster-addons" || { echo "legacy composite cluster-addons must not exist" >&2; exit 1; }
test ! -f "${argo}/security/pod-security-policy.yaml" || { echo "removed PodSecurityPolicy manifest must not exist" >&2; exit 1; }
must_not_contain "${argo}/management/argocd/rbac/rbac.yaml" "name: argocd-applications"
must_not_contain "${argo}/management/argocd/config/argocd-cm-health.yaml" "security.istio.io_PeerAuthentication"

for overlay in local azure-staging azure-prod; do
  need_file "${argo}/overlays/${overlay}/kustomization.yaml"
  kubectl kustomize "${argo}/overlays/${overlay}" >/dev/null
done

must_contain "${argo}/overlays/local/kustomization.yaml" "applications/foundation/networking/cert-manager-local"
must_contain "${argo}/overlays/local/kustomization.yaml" "management/argocd/config"
must_contain "${argo}/overlays/local/kustomization.yaml" "management/argocd/rbac"
must_contain "${argo}/overlays/local/kustomization.yaml" "applications/foundation/security/policy-engine/local"
must_contain "${argo}/overlays/local/kustomization.yaml" "applications/platform/observability/monitoring-local"
must_contain "${argo}/overlays/local/kustomization.yaml" "applications/services/configuration/config-server/local"
must_contain "${argo}/overlays/local/kustomization.yaml" "applications/services/networking/api-gateway/local"
must_not_contain "${argo}/overlays/local/kustomization.yaml" "applications/workloads/api-platform"
for overlay in azure-staging azure-prod; do
  must_contain "${argo}/namespaces/${overlay}/kustomization.yaml" "platform-identity.yaml"
  must_contain "${argo}/overlays/${overlay}/kustomization.yaml" "projects/identity"
  must_not_contain "${argo}/overlays/${overlay}/kustomization.yaml" "applications/platform/identity/keycloak"
done

for overlay in azure-staging azure-prod; do
  must_not_contain "${argo}/overlays/${overlay}/kustomization.yaml" "applications/foundation/security/external-secrets"
  must_not_contain "${argo}/overlays/${overlay}/kustomization.yaml" "applications/foundation/security/policy-engine"
  must_not_contain "${argo}/overlays/${overlay}/kustomization.yaml" "applications/foundation/networking/cert-manager"
  must_not_contain "${argo}/overlays/${overlay}/kustomization.yaml" "applications/platform/observability/monitoring"
  must_not_contain "${argo}/overlays/${overlay}/kustomization.yaml" "applications/services/"
done
must_contain "${argo}/applications/foundation/security/external-secrets/application.yaml" "path: argoCD/helm/foundation/security/external-secrets"
must_contain "${external_secrets}/values.yaml" "installCRDs: true"
must_contain "${argo}/foundation/security/external-secrets/azure/key-vault-secret-store.yaml" "authType: WorkloadIdentity"

must_contain "${argo}/applications/services/configuration/config-server/local/application.yaml" "sync-wave: \"-10\""
must_contain "${argo}/applications/services/networking/api-gateway/local/application.yaml" "sync-wave: \"0\""
must_contain "${argo}/applications/platform/runtime/consul-local/consul.yaml" "sync-wave: \"-15\""
must_contain "${argo}/applications/foundation/networking/cert-manager-local/application.yaml" "sync-wave: \"-20\""
must_contain "${argo}/applications/foundation/networking/cert-manager-local/application.yaml" "platform.spaceup.io/migration-mode: manual-sync-required"
must_contain "${argo}/applications/platform/observability/monitoring-local/application.yaml" "platform.spaceup.io/migration-mode: manual-sync-required"
must_contain "${argo}/applications/foundation/security/policy-engine/local/application.yaml" "sync-wave: \"-17\""
must_contain "${argo}/applications/platform/observability/monitoring-local/application.yaml" "sync-wave: \"-18\""

while IFS= read -r app; do
  if grep -Fq 'automated:' "$app"; then
    echo "staging and production Applications must not auto-sync a mutable revision: $app" >&2
    exit 1
  fi
done < <(find "${argo}/applications" -type f \( -path '*/staging/*.yaml' -o -path '*/prod/*.yaml' \))

must_not_contain "${argo}/bootstrap/argocd-bootstrap-azure-staging.yaml" "automated:"
must_not_contain "${argo}/bootstrap/argocd-bootstrap-azure-prod.yaml" "automated:"

render config-ingestor "$config" spaceup-dev -f "$config/values.yaml" -f "$config/values-dev.yaml" -f "$config/values-local.yaml"
render gateway-ingestor "$gateway" spaceup-dev -f "$gateway/values.yaml" -f "$gateway/values-dev.yaml" -f "$gateway/values-local.yaml"
render config-ingestor-contract "$config" spaceup-staging -f "$config/values.yaml" -f "$config/values-contract-test.yaml"
render gateway-ingestor-contract "$gateway" spaceup-staging -f "$gateway/values.yaml" -f "$gateway/values-contract-test.yaml"
render foundation-cert-manager-local "$cert" platform-system -f "$cert/values.yaml" -f "$cert/values-local.yaml"
render external-secrets-contract "$external_secrets" external-secrets -f "$external_secrets/values.yaml"
render foundation-policy-engine-local "$policy_engine" kyverno -f "$policy_engine/values.yaml" -f "$policy_engine/values-local.yaml"
render platform-monitoring-local "$monitoring" platform-system -f "$monitoring/values.yaml" -f "$monitoring/values-local.yaml"
render platform-consul-local "$consul" platform-runtime -f "$consul/values.yaml" -f "$consul/values-local.yaml"
render platform-kafka-local "$kafka" platform-runtime -f "$kafka/values.yaml" -f "$kafka/values-local.yaml"
render platform-keycloak-contract "$keycloak" platform-identity -f "$keycloak/values.yaml" -f "$keycloak/values-azure.yaml" -f "$keycloak/values-contract-test.yaml"

echo "GitOps architecture preflight passed."
