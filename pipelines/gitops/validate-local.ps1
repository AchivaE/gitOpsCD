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

function Render-Chart {
    param([string]$Release, [string]$Chart, [string]$Namespace, [string[]]$Values)
    helm lint $Chart @Values
    if ($LASTEXITCODE -ne 0) { throw "Helm lint failed: $Release" }
    helm template $Release $Chart --namespace $Namespace @Values | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Helm render failed: $Release" }
}

$consulChart = Join-Path $repositoryRoot 'argoCD\helm\platform\consul'
$consulApp = Join-Path $argoRoot 'applications\platform-consul-local\consul.yaml'
$consulProject = Join-Path $argoRoot 'projects\platform-runtime\project.yaml'

Require-Path $consulChart
Require-Path $consulApp
Require-Path $consulProject
Require-Text $consulApp 'name: platform-consul-local'
Require-Text $consulApp 'path: argoCD/helm/platform/consul'
Require-Text $consulApp 'SkipDryRunOnMissingResource=true'
Require-Text $consulProject 'kind: CustomResourceDefinition'
Require-Text $consulProject 'kind: MutatingWebhookConfiguration'
Require-Text (Join-Path $argoRoot 'overlays\local\kustomization.yaml') '../../applications/platform-consul-local'
Require-Text (Join-Path $argoRoot 'namespaces\local\platform-runtime.yaml') 'name: platform-runtime'

Render-Chart 'config-ingestor' (Join-Path $repositoryRoot 'argoCD\helm\services\config-ingestor') 'spaceup-dev' @(
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\config-ingestor\values.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\config-ingestor\values-dev.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\config-ingestor\values-local.yaml')
)
Render-Chart 'gateway-ingestor' (Join-Path $repositoryRoot 'argoCD\helm\services\gateway-ingestor') 'spaceup-dev' @(
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\gateway-ingestor\values.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\gateway-ingestor\values-dev.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\services\gateway-ingestor\values-local.yaml')
)
Render-Chart 'cluster-addons-local' (Join-Path $repositoryRoot 'argoCD\helm\cluster-addons') 'platform-system' @(
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\cluster-addons\values.yaml'),
    '-f', (Join-Path $repositoryRoot 'argoCD\helm\cluster-addons\values-local.yaml')
)
Render-Chart 'platform-consul-local' $consulChart 'platform-runtime' @(
    '-f', (Join-Path $consulChart 'values.yaml'),
    '-f', (Join-Path $consulChart 'values-local.yaml')
)

kubectl kustomize (Join-Path $argoRoot 'overlays\local') | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Local Argo overlay render failed.' }

Write-Host 'Local GitOps render preflight passed.' -ForegroundColor Green
