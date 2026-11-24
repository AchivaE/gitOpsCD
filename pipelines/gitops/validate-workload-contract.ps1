[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workloadsRoot = Join-Path $repositoryRoot 'argoCD\helm\workloads'
$applicationsRoot = Join-Path $repositoryRoot 'argoCD\argo\applications\workloads'

function Require-Text {
    param([string]$Path, [string]$Text)
    if (-not (Select-String -LiteralPath $Path -SimpleMatch $Text -Quiet)) {
        throw "Missing '$Text' in $Path"
    }
}

if (-not (Test-Path -LiteralPath $workloadsRoot)) {
    throw "Missing workloads catalogue: $workloadsRoot"
}

$charts = Get-ChildItem -LiteralPath $workloadsRoot -Recurse -File -Filter Chart.yaml
foreach ($chart in $charts) {
    $serviceRoot = Split-Path $chart.FullName -Parent
    $serviceName = Split-Path $serviceRoot -Leaf
    $domainRoot = Split-Path $serviceRoot -Parent
    $domain = Split-Path $domainRoot -Leaf
    $contract = Join-Path $serviceRoot 'service-contract.yaml'

    foreach ($required in @($contract, (Join-Path $serviceRoot 'values.yaml'), (Join-Path $serviceRoot 'values-local.yaml'), (Join-Path $serviceRoot 'values-staging.yaml'), (Join-Path $serviceRoot 'values-prod.yaml'))) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Missing workload contract file: $required" }
    }
    foreach ($field in @('apiVersion: spaceup.io/v1alpha1', 'kind: WorkloadContract', "name: $serviceName", "domain: $domain", 'owner:', 'exposure:', 'interfaceContract:', 'immutable: true', 'classification:', 'rpo:', 'rto:', 'migration:', 'rollback:', 'procedure:', 'compatibility:')) {
        Require-Text $contract $field
    }

    $localManifest = helm template "contract-$serviceName" $serviceRoot --namespace "spaceup-$domain-dev" -f (Join-Path $serviceRoot 'values.yaml') -f (Join-Path $serviceRoot 'values-local.yaml')
    if ($LASTEXITCODE -ne 0) { throw "Local render failed: $serviceRoot" }
    foreach ($requiredKind in @('kind: ServiceAccount', 'kind: Deployment', 'kind: Service', 'kind: NetworkPolicy', 'startupProbe:', 'readinessProbe:', 'livenessProbe:', 'resources:')) {
        if ($localManifest -notmatch [regex]::Escape($requiredKind)) { throw "Missing rendered workload control '$requiredKind': $serviceRoot" }
    }
    if ($localManifest -match '(?m)^kind: Secret$') { throw "Workload chart must not create a Kubernetes Secret: $serviceRoot" }

    foreach ($profile in @('staging', 'prod')) {
        $manifest = helm template "contract-$serviceName" $serviceRoot --namespace "spaceup-$domain-$profile" -f (Join-Path $serviceRoot 'values.yaml') -f (Join-Path $serviceRoot "values-$profile.yaml")
        if ($LASTEXITCODE -ne 0) { throw "$profile render failed: $serviceRoot" }
        if ($manifest -notmatch '@sha256:[a-f0-9]{64}') { throw "$profile must render an OCI image digest: $serviceRoot" }
    }

    $profiles = @{ dev = 'dev'; staging = 'staging'; prod = 'prod' }
    foreach ($entry in $profiles.GetEnumerator()) {
        $application = Join-Path $applicationsRoot "$domain\$serviceName\$($entry.Key)\application.yaml"
        if (-not (Test-Path -LiteralPath $application)) { throw "Missing explicit Argo Application: $application" }
        Require-Text $application "name: $($entry.Value)-$serviceName"
        Require-Text $application "path: argoCD/helm/workloads/$domain/$serviceName"
        if ($entry.Key -ne 'dev') {
            if (Select-String -LiteralPath $application -SimpleMatch 'targetRevision: main' -Quiet) {
                throw "Mutable main is forbidden for $($entry.Key): $application"
            }
            if (-not (Select-String -LiteralPath $application -Pattern 'targetRevision:\s+([0-9a-f]{40}|v[0-9][^\s]*)' -Quiet)) {
                throw "Staging/prod requires an immutable commit SHA or protected v* tag: $application"
            }
        }
    }
}

Write-Host "Workload deployment-contract preflight passed ($($charts.Count) workload chart(s))." -ForegroundColor Green
