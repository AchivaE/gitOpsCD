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

$init = $null
if (Test-Path -LiteralPath $recoveryFile) {
    # Resume safely after a workstation interruption. The existing recovery
    # material is authoritative and is never overwritten or regenerated.
    $init = Get-Content -Raw -LiteralPath $recoveryFile | ConvertFrom-Json
    if ($null -eq $init.root_token -or $init.unseal_keys_b64.Count -lt 3) {
        throw "Recovery file is incomplete: $recoveryFile. Do not reinitialize Vault; recover the original keys before continuing."
    }
    Write-Host "Existing local recovery material found; resuming initialization without rotating Vault keys."
}
else {
    $init = (& minikube kubectl -- exec -n $namespace $pod -- env `
        "VAULT_ADDR=http://127.0.0.1:8200" vault operator init -format=json | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0 -or $null -eq $init.root_token) {
        throw "Vault initialization failed. If Vault was already initialized, recover its existing local keys instead of rerunning this script."
    }

    New-Item -ItemType Directory -Force -Path $RecoveryDirectory | Out-Null
    $init | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $recoveryFile -NoNewline -Encoding utf8
}

# Windows PowerShell treats a native process exit code as a terminating error
# under ErrorActionPreference=Stop. Vault deliberately returns 2 while sealed,
# so relax that preference only for this expected status probe.
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $sealStatusJson = & minikube kubectl -- exec -n $namespace $pod -- env `
        "VAULT_ADDR=http://127.0.0.1:8200" vault status -format=json 2>$null
    $sealStatusExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
# Vault returns 2 while sealed. That is an expected state during first local
# bootstrap, not a script failure.
if ($sealStatusExitCode -notin @(0, 2)) {
    throw "Unable to read Vault seal status."
}
$sealStatus = $sealStatusJson | ConvertFrom-Json
if ($sealStatus.sealed) {
    foreach ($key in $init.unseal_keys_b64[0..2]) {
        & minikube kubectl -- exec -n $namespace $pod -- env `
            "VAULT_ADDR=http://127.0.0.1:8200" vault operator unseal $key | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Vault unseal failed. Keep the recovery material at $recoveryFile and retry this script; it will resume safely."
        }
    }
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

# Vault is now healthy. Refresh both Applications; the local store shares the
# Vault wave, so App-of-Apps does not need to wait for a later child wave.
Invoke-MinikubeKubectl annotate application platform-vault-local -n argocd `
    argocd.argoproj.io/refresh=hard --overwrite | Out-Null
Invoke-MinikubeKubectl annotate application argocd-bootstrap-local -n argocd `
    argocd.argoproj.io/refresh=hard --overwrite | Out-Null

Write-Host "Vault local initialized and unsealed. Recovery material saved only on this workstation: $recoveryFile"
Write-Host "Move that file to a protected local password manager, then remove it from the workstation when this local validation is complete."
Write-Host "Argo CD will create the local Vault ClusterSecretStore in the same synchronization wave; no Vault token was stored in Git or Kubernetes."
