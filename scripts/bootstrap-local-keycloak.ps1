[CmdletBinding()]
param(
    [string]$Namespace = 'platform-identity'
)

$ErrorActionPreference = 'Stop'

function New-LocalSecret {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][hashtable]$Values
    )

    $arguments = @('create', 'secret', 'generic', $Name, '--namespace', $Namespace, '--dry-run=client', '-o', 'yaml')
    foreach ($entry in $Values.GetEnumerator()) {
        $arguments += "--from-literal=$($entry.Key)=$($entry.Value)"
    }

    $manifest = & minikube kubectl -- @arguments
    if ($LASTEXITCODE -ne 0) { throw "Unable to render secret '$Name'." }
    $manifest | & minikube kubectl -- apply -f -
    if ($LASTEXITCODE -ne 0) { throw "Unable to apply secret '$Name'." }
}

if (-not (Get-Command minikube -ErrorAction SilentlyContinue)) {
    throw 'minikube is required. Start the local cluster before bootstrapping Keycloak.'
}

& minikube kubectl -- get namespace $Namespace | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Namespace '$Namespace' does not exist. Sync argocd-bootstrap-local first." }

$adminPassword = Read-Host 'Keycloak local admin password' -AsSecureString
$adminBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPassword)
try {
    $adminPlainText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($adminBstr)
    if ([string]::IsNullOrWhiteSpace($adminPlainText)) { throw 'The Keycloak admin password cannot be empty.' }

    $passwordBytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($passwordBytes)
    $databasePassword = [Convert]::ToBase64String($passwordBytes)

    New-LocalSecret -Name 'keycloak-local-admin' -Values @{ 'admin-password' = $adminPlainText }
    New-LocalSecret -Name 'keycloak-local-db' -Values @{
        password            = $databasePassword
        'postgres-password' = $databasePassword
    }
}
finally {
    if ($adminBstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($adminBstr) }
    Remove-Variable adminPlainText, databasePassword, passwordBytes -ErrorAction SilentlyContinue
}

Write-Host "Local Keycloak secrets are ready in namespace '$Namespace'. You may now sync platform-keycloak-local in Argo CD."
