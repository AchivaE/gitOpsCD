[CmdletBinding()]
param(
    [string]$RecoveryDirectory = (Join-Path $env:LOCALAPPDATA "SpaceUp\vault-local")
)

$ErrorActionPreference = "Stop"

$namespace = "platform-security"
$pod = "vault-0"
$recoveryFile = Join-Path $RecoveryDirectory "vault-init.json"

function Invoke-MinikubeKubectl {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & minikube kubectl -- @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "minikube kubectl failed: $($Arguments -join ' ')"
    }
}

function Invoke-Vault {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    & minikube kubectl -- exec -n $namespace $pod -- env `
        "VAULT_ADDR=http://127.0.0.1:8200" "VAULT_TOKEN=$script:rootToken" vault @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Vault command failed: vault $($Arguments -join ' ')"
    }
}

if (Test-Path -LiteralPath $recoveryFile) {
    throw "Recovery file already exists: $recoveryFile. Refusing to initialize or overwrite a local Vault. Use the saved recovery keys to unseal it."
}

Invoke-MinikubeKubectl get serviceaccount external-secrets -n external-secrets | Out-Null

$deadline = (Get-Date).AddMinutes(5)
do {
    $phase = & minikube kubectl -- get pod $pod -n $namespace -o jsonpath='{.status.phase}'
    if ($LASTEXITCODE -eq 0 -and $phase -eq "Running") { break }
    Start-Sleep -Seconds 3
} while ((Get-Date) -lt $deadline)

if ($phase -ne "Running") {
    throw "Vault pod $pod is not Running. Wait for platform-vault-local to be Synced, then retry."
}

$init = (& minikube kubectl -- exec -n $namespace $pod -- env `
    "VAULT_ADDR=http://127.0.0.1:8200" vault operator init -format=json | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or $null -eq $init.root_token) {
    throw "Vault initialization failed. If Vault was already initialized, recover its existing local keys instead of rerunning this script."
}

New-Item -ItemType Directory -Force -Path $RecoveryDirectory | Out-Null
$init | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $recoveryFile -NoNewline -Encoding utf8

foreach ($key in $init.unseal_keys_b64[0..2]) {
    Invoke-MinikubeKubectl exec -n $namespace $pod -- env `
        "VAULT_ADDR=http://127.0.0.1:8200" vault operator unseal $key | Out-Null
}

$script:rootToken = $init.root_token

$enabledSecrets = (Invoke-Vault @("secrets", "list", "-format=json") | ConvertFrom-Json)
if (-not ($enabledSecrets.PSObject.Properties.Name -contains "kv/")) {
    Invoke-Vault @("secrets", "enable", "-path=kv", "kv-v2") | Out-Null
}

$enabledAuth = (Invoke-Vault @("auth", "list", "-format=json") | ConvertFrom-Json)
if (-not ($enabledAuth.PSObject.Properties.Name -contains "kubernetes/")) {
    Invoke-Vault @("auth", "enable", "kubernetes") | Out-Null
}

Invoke-Vault @("write", "auth/kubernetes/config", "kubernetes_host=https://kubernetes.default.svc") | Out-Null

@'
path "kv/data/platform/*" {
  capabilities = ["read"]
}
'@ | & minikube kubectl -- exec -i -n $namespace $pod -- env `
    "VAULT_ADDR=http://127.0.0.1:8200" "VAULT_TOKEN=$script:rootToken" vault policy write external-secrets -
if ($LASTEXITCODE -ne 0) {
    throw "Failed to write the least-privilege External Secrets policy."
}

Invoke-Vault @(
    "write", "auth/kubernetes/role/external-secrets",
    "bound_service_account_names=external-secrets",
    "bound_service_account_namespaces=external-secrets",
    "policies=external-secrets",
    "audience=vault",
    "ttl=1h"
) | Out-Null

# This is a non-sensitive proof record only. Workload credentials are never
# seeded by this script or committed to Git.
Invoke-Vault @("kv", "put", "kv/platform/bootstrap", "status=ready") | Out-Null

$storeDeadline = (Get-Date).AddMinutes(5)
do {
    & minikube kubectl -- get application external-secrets-vault-local-store -n argocd -o name 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 3
} while ((Get-Date) -lt $storeDeadline)

if ($LASTEXITCODE -ne 0) {
    throw "The Root Application did not create external-secrets-vault-local-store within five minutes. Inspect argocd-bootstrap-local before retrying."
}

Invoke-MinikubeKubectl annotate application external-secrets-vault-local-store -n argocd `
    argocd.argoproj.io/refresh=hard --overwrite | Out-Null

Write-Host "Vault local initialized and unsealed. Recovery material saved only on this workstation: $recoveryFile"
Write-Host "Move that file to a protected local password manager, then remove it from the workstation when this local validation is complete."
Write-Host "The ClusterSecretStore will now authenticate through Kubernetes Auth; no Vault token was stored in Git or Kubernetes."
