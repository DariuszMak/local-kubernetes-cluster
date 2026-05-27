#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install HashiCorp Vault (dev mode) into the running k3d cluster
    and seed it with secrets from .dev.env.

.NOTES
    Requires: helm, kubectl, vault CLI (for seeding from outside the cluster)
    Vault is exposed on http://localhost:8200 via port-forward for local access.
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

# -- 2. Create namespace ------------------------------------------------------
$ErrorActionPreference = "Continue"
kubectl get namespace $Namespace 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "-> Creating namespace '$Namespace'..." -ForegroundColor Cyan
    kubectl create namespace $Namespace
}
$ErrorActionPreference = "Stop"

# -- 3. Install / upgrade Vault -----------------------------------------------
Write-Host "-> Installing Vault into k3d (dev mode)..." -ForegroundColor Cyan
helm upgrade --install $ReleaseName $ChartName `
    --namespace $Namespace `
    --values $ValuesFile `
    --wait --timeout 120s

# -- 4. Wait for Vault pod ready ----------------------------------------------
Write-Host "-> Waiting for Vault pod to be ready..." -ForegroundColor Cyan
kubectl wait pod `
    --namespace $Namespace `
    --selector "app.kubernetes.io/name=vault,component=server" `
    --for condition=Ready `
    --timeout 90s

# -- 5. Port-forward Vault in the background ----------------------------------
Write-Host "-> Starting port-forward vault:8200 -> localhost:$LocalPort ..." -ForegroundColor Cyan

# Kill any existing port-forward on 8200
$ErrorActionPreference = "Continue"
$pfProc = Get-NetTCPConnection -LocalPort $LocalPort -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    Where-Object { $_ -gt 0 }
if ($pfProc) {
    $pfProc | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
}
$ErrorActionPreference = "Stop"

$pfJob = Start-Process kubectl `
    -ArgumentList "port-forward", "-n", $Namespace, "svc/vault", "${LocalPort}:8200" `
    -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 3
Write-Host "   Port-forward PID: $($pfJob.Id)" -ForegroundColor DarkGray

# -- 6. Seed secrets ----------------------------------------------------------
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

# -- 7. Configure Vault Agent Injector policy ---------------------------------
Write-Host "-> Configuring Vault policy for app..." -ForegroundColor Cyan

$policy = @"
path "secret/data/python-project/*" {
  capabilities = ["read"]
}
"@
$policy | vault policy write python-project-policy -

# -- 8. Enable Kubernetes auth -------------------------------------------------
Write-Host "-> Enabling Kubernetes auth method..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
vault auth enable kubernetes 2>$null
$ErrorActionPreference = "Stop"

# Get k8s host from inside the cluster
$k8sHost = kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"
$caCert  = kubectl config view --minify --raw -o jsonpath="{.clusters[0].cluster.certificate-authority-data}"

# Get the vault SA token for auth config
$vaultSaToken = kubectl exec -n $Namespace vault-0 -- `
    sh -c 'cat /var/run/secrets/kubernetes.io/serviceaccount/token' 2>$null
$vaultCaCert  = kubectl exec -n $Namespace vault-0 -- `
    sh -c 'cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt' 2>$null

$ErrorActionPreference = "Continue"
vault write auth/kubernetes/config `
    kubernetes_host="$k8sHost" `
    kubernetes_ca_cert="$vaultCaCert" `
    token_reviewer_jwt="$vaultSaToken" 2>$null
$ErrorActionPreference = "Stop"

# Create a role that the app's service account can use
vault write auth/kubernetes/role/python-project `
    bound_service_account_names=python-project `
    bound_service_account_namespaces=default,dev `
    policies=python-project-policy `
    ttl=1h

Write-Host ""
Write-Host "Vault is running in k3d" -ForegroundColor Green
Write-Host "   UI      : http://localhost:8200/ui  (token: $RootToken)"
Write-Host "   Secrets : vault kv get $SecretPath"
