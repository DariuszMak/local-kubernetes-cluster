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
$ChartRepo   = "hashicorp"
$ChartName   = "hashicorp/vault"
$ValuesFile  = "helm/vault/values.yaml"
$SecretPath  = "secret/python-project/dev"
$RootToken   = "root"
$LocalPort   = "8200"

# -- 1. Add HashiCorp Helm repo -----------------------------------------------
Write-Host "-> Adding HashiCorp Helm repo..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
helm repo add $ChartRepo https://helm.releases.hashicorp.com 2>$null
$ErrorActionPreference = "Stop"
helm repo update

# -- 2. Create namespace -------------------------------------------------------
$ErrorActionPreference = "Continue"
$nsOut = kubectl get namespace $Namespace 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "-> Creating namespace '$Namespace'..." -ForegroundColor Cyan
    kubectl create namespace $Namespace
}
$ErrorActionPreference = "Stop"

# -- 3. Install / upgrade Vault ------------------------------------------------
Write-Host "-> Installing Vault into k3d (dev mode)..." -ForegroundColor Cyan
helm upgrade --install $ReleaseName $ChartName `
    --namespace $Namespace `
    --values $ValuesFile `
    --wait --timeout 120s

# -- 4. Wait for Vault pod ready -----------------------------------------------
Write-Host "-> Waiting for Vault pod to be ready..." -ForegroundColor Cyan
kubectl wait pod `
    --namespace $Namespace `
    --selector "app.kubernetes.io/name=vault,component=server" `
    --for condition=Ready `
    --timeout 90s

# -- 5. Port-forward Vault in the background -----------------------------------
Write-Host "-> Starting port-forward vault:8200 -> localhost:$LocalPort ..." -ForegroundColor Cyan

$ErrorActionPreference = "Continue"
Get-NetTCPConnection -LocalPort $LocalPort -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    Where-Object { $_ -gt 0 } |
    ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
$ErrorActionPreference = "Stop"

Start-Process kubectl `
    -ArgumentList "port-forward", "-n", $Namespace, "svc/vault", "${LocalPort}:8200" `
    -WindowStyle Hidden
Start-Sleep -Seconds 3

# -- 6. Seed secrets -----------------------------------------------------------
$env:VAULT_ADDR  = "http://127.0.0.1:$LocalPort"
$env:VAULT_TOKEN = $RootToken

Write-Host "-> Seeding secrets into Vault from .dev.env ..." -ForegroundColor Cyan

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
    vault kv put $SecretPath @kvArgs
    Write-Host "   Seeded $($kvArgs.Count) secret(s) to '$SecretPath'" -ForegroundColor DarkGray
}

# -- 7. Write Vault policy -----------------------------------------------------
Write-Host "-> Configuring Vault policy for app..." -ForegroundColor Cyan
$policy = 'path "secret/data/python-project/*" { capabilities = ["read"] }'
$policy | vault policy write python-project-policy -

# -- 8. Enable and configure Kubernetes auth -----------------------------------
Write-Host "-> Configuring Kubernetes auth method..." -ForegroundColor Cyan

$ErrorActionPreference = "Continue"
vault auth enable kubernetes 2>$null
$ErrorActionPreference = "Stop"

# The cleanest approach for k3d: tell Vault to use its own pod's service
# account token and the in-cluster Kubernetes API address.
# This avoids fragile multi-line cert extraction via kubectl exec.
$configResult = kubectl exec -n $Namespace vault-0 -- `
    vault write auth/kubernetes/config `
        kubernetes_host="https://kubernetes.default.svc.cluster.local" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Kubernetes auth config step returned non-zero: $configResult"
    Write-Warning "The injector may not authenticate. Re-run 'task vault-k3d' after the cluster settles."
} else {
    Write-Host "   Kubernetes auth configured (in-cluster token + CA)" -ForegroundColor DarkGray
}

# -- 9. Create the app role ----------------------------------------------------
Write-Host "-> Creating Kubernetes auth role for app..." -ForegroundColor Cyan

# The app runs in 'default' namespace (Helm/Tilt) and 'dev' (Kustomize).
# ServiceAccount name matches the Helm release name.
vault write auth/kubernetes/role/python-project `
    bound_service_account_names="python-project,default" `
    bound_service_account_namespaces="default,dev" `
    policies=python-project-policy `
    ttl=1h

Write-Host ""
Write-Host "Vault is running in k3d" -ForegroundColor Green
Write-Host "   UI      : http://localhost:8200/ui  (token: $RootToken)"
Write-Host "   Secrets : vault kv get $SecretPath"
Write-Host ""
Write-Host "To verify auth config inside the cluster:"
Write-Host "   kubectl exec -n vault vault-0 -- vault read auth/kubernetes/config"