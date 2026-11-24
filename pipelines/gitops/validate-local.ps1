[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$argoRoot = Join-Path $repositoryRoot 'argoCD\argo'

function Require-Path {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required path: $Path"
    }
}

function Require-Text {
    param([string]$Path, [string]$Text)
    Require-Path $Path
    if (-not (Select-String -LiteralPath $Path -SimpleMatch $Text -Quiet)) {
        throw "Missing required configuration '$Text' in $Path"
    }
}

function Require-TextAbsent {
    param([string]$Path, [string]$Text)
    Require-Path $Path
    if (Select-String -LiteralPath $Path -SimpleMatch $Text -Quiet) {
        throw "Forbidden configuration '$Text' in $Path"
    }
}

function Render-Chart {
    param([string]$Release, [string]$Chart, [string]$Namespace, [string[]]$Values)
    helm lint $Chart @Values
    if ($LASTEXITCODE -ne 0) { throw "Helm lint failed: $Release" }
    helm template $Release $Chart --namespace $Namespace @Values | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Helm render failed: $Release" }
}

$consulChart = Join-Path $repositoryRoot 'argoCD\helm\platform\runtime\consul'
$keycloakChart = Join-Path $repositoryRoot 'argoCD\helm\platform\identity\keycloak'
$kafkaChart = Join-Path $repositoryRoot 'argoCD\helm\platform\eventing\kafka'
$certManagerChart = Join-Path $repositoryRoot 'argoCD\helm\foundation\networking\cert-manager'
$externalSecretsChart = Join-Path $repositoryRoot 'argoCD\helm\foundation\security\external-secrets'
$policyEngineChart = Join-Path $repositoryRoot 'argoCD\helm\foundation\security\policy-engine'
$monitoringChart = Join-Path $repositoryRoot 'argoCD\helm\platform\observability\monitoring'
$legacyPlatformChart = Join-Path $repositoryRoot 'argoCD\helm\platform\Chart.yaml'
$consulApp = Join-Path $argoRoot 'applications\platform\runtime\consul-local\consul.yaml'
$consulProject = Join-Path $argoRoot 'projects\platform-runtime\project.yaml'
$kafkaApp = Join-Path $argoRoot 'applications\platform\eventing\kafka-local\kafka.yaml'
$configLocalApp = Join-Path $argoRoot 'applications\services\configuration\config-server\local\application.yaml'
$gatewayLocalApp = Join-Path $argoRoot 'applications\services\networking\api-gateway\local\application.yaml'
$externalSecretsApp = Join-Path $argoRoot 'applications\foundation\security\external-secrets\application.yaml'
$azureSecretStore = Join-Path $argoRoot 'foundation\security\external-secrets\azure\key-vault-secret-store.yaml'
$policyEngineLocalApp = Join-Path $argoRoot 'applications\foundation\security\policy-engine\local\application.yaml'

Require-Path $consulChart
Require-Path $keycloakChart
Require-Path $kafkaChart
Require-Path $certManagerChart
Require-Path $externalSecretsChart
Require-Path $policyEngineChart
Require-Path $monitoringChart
if (Test-Path -LiteralPath $legacyPlatformChart) {
    throw "Legacy platform umbrella chart must not exist: $legacyPlatformChart"
}
Require-Path $consulApp
Require-Path $consulProject
Require-Text $consulApp 'name: platform-consul-local'
Require-Text $consulApp 'path: argoCD/helm/platform/runtime/consul'
Require-Text $consulProject 'kind: ClusterRole'
Require-Text $consulProject 'kind: PersistentVolumeClaim'
Require-Text $consulProject 'kind: NetworkPolicy'
Require-Path $kafkaApp
Require-Text $kafkaApp 'name: platform-kafka-local'
Require-Text $kafkaApp 'path: argoCD/helm/platform/eventing/kafka'
Require-TextAbsent (Join-Path $argoRoot 'overlays\local\kustomization.yaml') '../../applications/platform/eventing/kafka-local'
Require-Text (Join-Path $argoRoot 'overlays\local\kustomization.yaml') '../../applications/platform/runtime/consul-local'
Require-Text (Join-Path $argoRoot 'namespaces\local\platform-runtime.yaml') 'name: platform-runtime'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-staging\kustomization.yaml') '../../applications/platform/runtime/consul-staging'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-prod\kustomization.yaml') '../../applications/platform/runtime/consul-prod'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-staging\kustomization.yaml') '../../applications/platform/identity/keycloak-staging'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-prod\kustomization.yaml') '../../applications/platform/identity/keycloak-prod'
Require-Text (Join-Path $argoRoot 'namespaces\azure-staging\kustomization.yaml') 'platform-identity.yaml'
Require-Text (Join-Path $argoRoot 'namespaces\azure-prod\kustomization.yaml') 'platform-identity.yaml'
Require-Text (Join-Path $argoRoot 'overlays\azure-staging\kustomization.yaml') '../../projects/identity'
Require-Text (Join-Path $argoRoot 'overlays\azure-prod\kustomization.yaml') '../../projects/identity'

Require-Path $externalSecretsApp
Require-Path $azureSecretStore
Require-Text $externalSecretsApp 'name: external-secrets-operator'
Require-Text $externalSecretsApp 'path: argoCD/helm/foundation/security/external-secrets'
Require-Text $externalSecretsApp 'sync-wave: "-20"'
Require-Text (Join-Path $externalSecretsChart 'values.yaml') 'installCRDs: true'
Require-Text $azureSecretStore 'kind: ClusterSecretStore'
Require-Text $azureSecretStore 'authType: WorkloadIdentity'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-staging\kustomization.yaml') '../../applications/foundation/security/external-secrets'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-staging\kustomization.yaml') '../../applications/foundation/security/policy-engine/staging'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-staging\kustomization.yaml') '../../applications/foundation/networking/cert-manager-staging'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-staging\kustomization.yaml') '../../applications/platform/observability/monitoring-staging'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-staging\kustomization.yaml') '../../applications/services/configuration/config-server/staging'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-staging\kustomization.yaml') '../../applications/services/networking/api-gateway/staging'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-prod\kustomization.yaml') '../../applications/foundation/security/external-secrets'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-prod\kustomization.yaml') '../../applications/foundation/security/policy-engine/prod'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-prod\kustomization.yaml') '../../applications/foundation/networking/cert-manager-prod'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-prod\kustomization.yaml') '../../applications/platform/observability/monitoring-prod'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-prod\kustomization.yaml') '../../applications/services/configuration/config-server/prod'
Require-TextAbsent (Join-Path $argoRoot 'overlays\azure-prod\kustomization.yaml') '../../applications/services/networking/api-gateway/prod'

Require-Path $policyEngineLocalApp
Require-Text $policyEngineLocalApp 'name: foundation-policy-engine-local'
Require-Text $policyEngineLocalApp 'path: argoCD/helm/foundation/security/policy-engine'
Require-Text $policyEngineLocalApp 'sync-wave: "-17"'
Require-Text (Join-Path $policyEngineChart 'values.yaml') 'enabled: true'
Require-Text (Join-Path $argoRoot 'projects\cluster-addons\project.yaml') 'namespace: kyverno'
Require-Text (Join-Path $argoRoot 'projects\cluster-addons\project.yaml') 'kind: ClusterPolicy'
Require-Text (Join-Path $argoRoot 'namespaces\local\namespace.yaml') 'platform.spaceup.io/policy-tier: baseline'
Require-Text (Join-Path $argoRoot 'overlays\local\kustomization.yaml') '../../applications/foundation/security/policy-engine/local'

Require-Path $configLocalApp
Require-Path $gatewayLocalApp
Require-Text $configLocalApp 'name: dev-config-ingestor'
Require-Text $configLocalApp 'path: argoCD/helm/services/configuration/config-server'
Require-Text $configLocalApp 'sync-wave: "-10"'
Require-Text $gatewayLocalApp 'name: dev-gateway-ingestor'
Require-Text $gatewayLocalApp 'path: argoCD/helm/services/networking/api-gateway'
Require-Text $gatewayLocalApp 'sync-wave: "0"'
Require-Text (Join-Path $argoRoot 'overlays\local\kustomization.yaml') '../../applications/services/configuration/config-server/local'
Require-Text (Join-Path $argoRoot 'overlays\local\kustomization.yaml') '../../applications/services/networking/api-gateway/local'
Require-Text (Join-Path $argoRoot 'applications\foundation\networking\cert-manager-local\application.yaml') 'platform.spaceup.io/migration-mode: manual-sync-required'
Require-Text (Join-Path $argoRoot 'applications\platform\observability\monitoring-local\application.yaml') 'platform.spaceup.io/migration-mode: manual-sync-required'

if (Test-Path -LiteralPath (Join-Path $argoRoot 'security\pod-security-policy.yaml')) {
    throw 'Removed Kubernetes PodSecurityPolicy manifest must not be restored; use Kyverno and Pod Security Admission instead.'
}
Require-TextAbsent (Join-Path $argoRoot 'management\argocd\rbac\rbac.yaml') 'name: argocd-applications'
Require-TextAbsent (Join-Path $argoRoot 'management\argocd\config\argocd-cm-health.yaml') 'security.istio.io_PeerAuthentication'
Require-Text (Join-Path $argoRoot 'overlays\local\kustomization.yaml') '../../management/argocd/config'
Require-Text (Join-Path $argoRoot 'overlays\local\kustomization.yaml') '../../management/argocd/rbac'

$deprecatedPlatformSource = Get-ChildItem -LiteralPath $argoRoot -Recurse -File -Filter '*.yaml' |
    Select-String -Pattern '^\s*path:\s*argoCD/helm/platform\s*$'
if ($deprecatedPlatformSource) {
    throw "The deprecated helm/platform umbrella chart is referenced by Argo: $($deprecatedPlatformSource.Path)"
}

$nonLocalApps = Get-ChildItem -LiteralPath (Join-Path $argoRoot 'applications') -Recurse -File -Filter '*.yaml' |
    Where-Object { $_.FullName -match '\\(staging|prod)\\' }
foreach ($app in $nonLocalApps) {
    if (Select-String -LiteralPath $app.FullName -Pattern 'automated:' -Quiet) {
        throw "Staging and production Applications must not auto-sync a mutable revision: $($app.FullName)"
    }
}

foreach ($bootstrap in @('bootstrap\argocd-bootstrap-azure-staging.yaml', 'bootstrap\argocd-bootstrap-azure-prod.yaml')) {
    Require-TextAbsent (Join-Path $argoRoot $bootstrap) 'automated:'
}

Render-Chart 'config-ingestor' (Join-Path $repositoryRoot 'argoCD\helm\services\configuration\config-server') 'spaceup-dev' @(
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\configuration\config-server\values.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\configuration\config-server\values-dev.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\configuration\config-server\values-local.yaml')
)
Render-Chart 'gateway-ingestor' (Join-Path $repositoryRoot 'argoCD\helm\services\networking\api-gateway') 'spaceup-dev' @(
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\networking\api-gateway\values.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\networking\api-gateway\values-dev.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\networking\api-gateway\values-local.yaml')
)
Render-Chart 'config-ingestor-contract' (Join-Path $repositoryRoot 'argoCD\helm\services\configuration\config-server') 'spaceup-staging' @(
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\configuration\config-server\values.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\configuration\config-server\values-contract-test.yaml')
)
Render-Chart 'gateway-ingestor-contract' (Join-Path $repositoryRoot 'argoCD\helm\services\networking\api-gateway') 'spaceup-staging' @(
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\networking\api-gateway\values.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\networking\api-gateway\values-contract-test.yaml')
)
Render-Chart 'foundation-cert-manager-local' $certManagerChart 'platform-system' @(
    '-f', (Join-Path $certManagerChart 'values.yaml'),
    '-f', (Join-Path $certManagerChart 'values-local.yaml')
)
Render-Chart 'external-secrets-contract' $externalSecretsChart 'external-secrets' @(
    '-f', (Join-Path $externalSecretsChart 'values.yaml')
)
Render-Chart 'foundation-policy-engine-local' $policyEngineChart 'kyverno' @(
    '-f', (Join-Path $policyEngineChart 'values.yaml'),
    '-f', (Join-Path $policyEngineChart 'values-local.yaml')
)
Render-Chart 'platform-monitoring-local' $monitoringChart 'platform-system' @(
    '-f', (Join-Path $monitoringChart 'values.yaml'),
    '-f', (Join-Path $monitoringChart 'values-local.yaml')
)
Render-Chart 'platform-consul-local' $consulChart 'platform-runtime' @(
    '-f', (Join-Path $consulChart 'values.yaml'),
    '-f', (Join-Path $consulChart 'values-local.yaml')
)
Render-Chart 'platform-kafka-local' $kafkaChart 'platform-runtime' @(
    '-f', (Join-Path $kafkaChart 'values.yaml'),
    '-f', (Join-Path $kafkaChart 'values-local.yaml')
)
Render-Chart 'platform-keycloak-contract' $keycloakChart 'platform-identity' @(
    '-f', (Join-Path $keycloakChart 'values.yaml'),
    '-f', (Join-Path $keycloakChart 'values-azure.yaml'),
    '-f', (Join-Path $keycloakChart 'values-contract-test.yaml')
)
$keycloakManifest = helm template platform-keycloak-contract $keycloakChart --namespace platform-identity @(
    '-f', (Join-Path $keycloakChart 'values.yaml'),
    '-f', (Join-Path $keycloakChart 'values-azure.yaml'),
    '-f', (Join-Path $keycloakChart 'values-contract-test.yaml')
)
if ($keycloakManifest -match 'kind: (ClusterRole|ClusterRoleBinding|CustomResourceDefinition)') {
    throw 'Keycloak must not create cluster-scoped resources.'
}

kubectl kustomize (Join-Path $argoRoot 'overlays\local') | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Local Argo overlay render failed.' }

& (Join-Path $PSScriptRoot 'validate-workload-contract.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Workload deployment-contract preflight failed.' }

Write-Host 'Local GitOps render preflight passed.' -ForegroundColor Green
