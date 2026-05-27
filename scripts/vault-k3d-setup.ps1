#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install HashiCorp Vault (dev mode) into the running k3d cluster,
    seed secrets, and configure Kubernetes auth so the Vault Agent
    Injector sidecar can authenticate from the app pod.

.NOTES
    Requires: helm, kubectl, vault CLI
    Vault is exposed on http://localhost:8200 via port-forward.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Namespace   = "vault"
$ReleaseName = "vault"
$ChartName   = "hashicorp/vault"
$ValuesFile  = "helm/vault/values.yaml"
$SecretPath  = "secret/python-project/dev"
$RootToken   = "root"
$LocalPort   = "8200"

# -- 1. Add HashiCorp Helm repo -----------------------------------------------
Write-Host "-> Adding HashiCorp Helm repo..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
helm repo add hashicorp https://helm.releases.hashicorp.com 2>$null
$ErrorActionPreference = "Stop"
helm repo update

# -- 2. Create namespace -------------------------------------------------------
$ErrorActionPreference = "Continue"
kubectl get namespace $Namespace 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "-> Creating namespace '$Namespace'..." -ForegroundColor Cyan
    kubectl create namespace $Namespace
}
$ErrorActionPreference = "Stop"

# -- 3. Install / upgrade Vault (no --wait; we poll manually below) -----------
Write-Host "-> Installing Vault into k3d (dev mode)..." -ForegroundColor Cyan
helm upgrade --install $ReleaseName $ChartName `
    --namespace $Namespace `
    --values $ValuesFile `
    --timeout 120s

# -- 4. Find the Vault pod (StatefulSet vault-0 in dev mode) ------------------
Write-Host "-> Waiting for Vault pod to become Ready..." -ForegroundColor Cyan
$vaultPod   = $null
$maxRetries = 60
for ($i = 1; $i -le $maxRetries; $i++) {
    $ErrorActionPreference = "Continue"
    $pods = kubectl get pods -n $Namespace -l "app.kubernetes.io/name=vault" `
        --field-selector="status.phase=Running" -o jsonpath="{.items[*].metadata.name}" 2>$null
    $ErrorActionPreference = "Stop"

    if ($pods) {
        # Pick the server pod (not the injector)
        foreach ($p in ($pods -split " ")) {
            if ($p -notmatch "injector") {
                $vaultPod = $p
                break
            }
        }
    }

    if ($vaultPod) {
        # Confirm it's actually Ready
        $ErrorActionPreference = "Continue"
        $ready = kubectl get pod $vaultPod -n $Namespace `
            -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}" 2>$null
        $ErrorActionPreference = "Stop"
        if ($ready -eq "True") { break }
    }

    if ($i -eq $maxRetries) {
        Write-Error "Vault pod did not become Ready after $maxRetries attempts."
        exit 1
    }
    Write-Host "   [$i/$maxRetries] Waiting... (pod: $vaultPod, ready: $ready)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
}
Write-Host "   Pod '$vaultPod' is Ready." -ForegroundColor DarkGray

# -- 5. Port-forward Vault svc -> localhost:8200 -------------------------------
Write-Host "-> Starting port-forward svc/vault -> localhost:$LocalPort ..." -ForegroundColor Cyan

# Kill anything already on that port
$ErrorActionPreference = "Continue"
Get-NetTCPConnection -LocalPort $LocalPort -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    Where-Object { $_ -gt 0 } |
    ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
$ErrorActionPreference = "Stop"
Start-Sleep -Seconds 1

$pfProc = Start-Process kubectl `
    -ArgumentList "port-forward", "-n", $Namespace, "svc/vault", "${LocalPort}:8200" `
    -WindowStyle Hidden -PassThru

# Poll until Vault actually answers (up to 30s)
$env:VAULT_ADDR  = "http://127.0.0.1:$LocalPort"
$env:VAULT_TOKEN = $RootToken
$vaultReady = $false
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep -Seconds 1
    $ErrorActionPreference = "Continue"
    $status = vault status 2>$null
    $rc = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    # exit code 0 = initialised+unsealed, 2 = sealed (still fine for dev)
    if ($rc -eq 0 -or $rc -eq 2) { $vaultReady = $true; break }
    Write-Host "   [$i/30] Waiting for port-forward..." -ForegroundColor DarkGray
}
if (-not $vaultReady) {
    Write-Error "Could not reach Vault at http://127.0.0.1:$LocalPort after port-forward."
    exit 1
}
Write-Host "   Port-forward up (PID $($pfProc.Id))" -ForegroundColor DarkGray

# -- 6. Seed secrets -----------------------------------------------------------
Write-Host "-> Seeding secrets from .dev.env ..." -ForegroundColor Cyan

$ErrorActionPreference = "Continue"
vault secrets enable -path=secret kv-v2 2>$null
$ErrorActionPreference = "Stop"

$kvArgs = @()
foreach ($line in Get-Content ".dev.env") {
    $line = $line.Trim()
    if ($line -eq "" -or $line.StartsWith("#") -or $line -notmatch "=") { continue }
    if ($line -match "^(HOST|PORT|PYTHONPATH)=") { continue }
    $parts = $line -split "=", 2
    $kvArgs += "$($parts[0].Trim())=$($parts[1].Trim())"
}
if ($kvArgs.Count -gt 0) {
    vault kv put $SecretPath @kvArgs | Out-Null
    Write-Host "   Seeded $($kvArgs.Count) secret(s) to '$SecretPath'" -ForegroundColor DarkGray
}

# -- 7. Vault policy -----------------------------------------------------------
Write-Host "-> Writing Vault policy..." -ForegroundColor Cyan
$policy = 'path "secret/data/python-project/*" { capabilities = ["read"] }'
$policy | vault policy write python-project-policy -

# -- 8. Kubernetes auth --------------------------------------------------------
Write-Host "-> Configuring Kubernetes auth method..." -ForegroundColor Cyan

$ErrorActionPreference = "Continue"
vault auth enable kubernetes 2>$null
$ErrorActionPreference = "Stop"

# Run the config command INSIDE the vault pod.
# When executed in-cluster, Vault auto-discovers the SA token and cluster CA.
# We only need to supply kubernetes_host.
Write-Host "   Running vault write auth/kubernetes/config inside pod '$vaultPod' ..." -ForegroundColor DarkGray
$ErrorActionPreference = "Continue"
$cfgOut = kubectl exec -n $Namespace $vaultPod -- `
    sh -c 'vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc.cluster.local"' 2>&1
$cfgRc = $LASTEXITCODE
$ErrorActionPreference = "Stop"

if ($cfgRc -ne 0) {
    Write-Error "Failed to configure Kubernetes auth inside Vault pod: $cfgOut"
    exit 1
}
Write-Host "   $cfgOut" -ForegroundColor DarkGray

# -- 9. App role ---------------------------------------------------------------
Write-Host "-> Creating auth role for python-project..." -ForegroundColor Cyan
# Covers Helm/Tilt deploy (default ns, SA=python-project or default)
# and Kustomize dev overlay (dev ns)
vault write auth/kubernetes/role/python-project `
    bound_service_account_names="python-project,default" `
    bound_service_account_namespaces="default,dev" `
    policies=python-project-policy `
    ttl=1h

# -- 10. Verify ----------------------------------------------------------------
Write-Host ""
Write-Host "Vault is running in k3d" -ForegroundColor Green
Write-Host "   UI      : http://localhost:$LocalPort/ui  (token: $RootToken)"
Write-Host "   Secrets : vault kv get $SecretPath"
Write-Host ""
Write-Host "Verify k8s auth config:"
Write-Host "   kubectl exec -n $Namespace $vaultPod -- vault read auth/kubernetes/config"