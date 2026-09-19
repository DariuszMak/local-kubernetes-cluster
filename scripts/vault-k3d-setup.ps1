#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Namespace   = "vault"
$SecretPath  = "secret/python-project/dev"
$RootToken   = "root"
$LocalPort   = "8200"
$ManifestFile = "k8s/vault/vault-dev.yaml"

Write-Host "-> Ensuring namespace '$Namespace' exists..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
kubectl get namespace $Namespace 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    kubectl create namespace $Namespace
}
$ErrorActionPreference = "Stop"

Write-Host "-> Deploying Vault dev server from $ManifestFile ..." -ForegroundColor Cyan
kubectl apply -f $ManifestFile

Write-Host "-> Waiting for Vault pod to become Ready..." -ForegroundColor Cyan
$vaultPod   = $null
$ready      = "False"
$maxRetries = 60
for ($i = 1; $i -le $maxRetries; $i++) {
    $ErrorActionPreference = "Continue"
    $allPods = kubectl get pods -n $Namespace -o jsonpath="{.items[*].metadata.name}" 2>$null
    $ErrorActionPreference = "Stop"

    if ($allPods) {
        foreach ($p in ($allPods -split "\s+")) {
            if ($p -and $p -match "^vault-" -and $p -notmatch "injector") {
                $vaultPod = $p
                break
            }
        }
    }

    if ($vaultPod) {
        $ErrorActionPreference = "Continue"
        $ready = kubectl get pod $vaultPod -n $Namespace `
            -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}" 2>$null
        $ErrorActionPreference = "Stop"
        if ($ready -eq "True") { break }
    }

    if ($i -eq $maxRetries) {
        Write-Host ""
        kubectl get pods -n $Namespace
        Write-Error "Vault pod did not become Ready after $maxRetries attempts."
        exit 1
    }
    Write-Host "   [$i/$maxRetries] Waiting... (pod: $vaultPod, ready: $ready)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
}
Write-Host "   Pod '$vaultPod' is Ready." -ForegroundColor DarkGray

Write-Host "-> Installing Vault Agent Injector via Helm..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
helm repo add hashicorp https://helm.releases.hashicorp.com 2>$null
$ErrorActionPreference = "Stop"
helm repo update

helm upgrade --install vault hashicorp/vault `
    --namespace $Namespace `
    --set "server.enabled=false" `
    --set "injector.enabled=true" `
    --set "injector.externalVaultAddr=http://vault.vault.svc.cluster.local:8200" `
    --timeout 120s

Write-Host "-> Port-forwarding svc/vault -> localhost:$LocalPort ..." -ForegroundColor Cyan
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

$env:VAULT_ADDR  = "http://127.0.0.1:$LocalPort"
$env:VAULT_TOKEN = $RootToken

$vaultUp = $false
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep -Seconds 1
    $ErrorActionPreference = "Continue"
    vault status 2>$null | Out-Null
    $rc = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($rc -eq 0 -or $rc -eq 2) { $vaultUp = $true; break }
    Write-Host "   [$i/30] Waiting for port-forward..." -ForegroundColor DarkGray
}
if (-not $vaultUp) {
    Write-Error "Could not reach Vault at http://127.0.0.1:$LocalPort"
    exit 1
}
Write-Host "   Port-forward up (PID $($pfProc.Id))" -ForegroundColor DarkGray

Write-Host "-> Seeding secrets from .dev.env ..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
vault secrets enable -path=secret kv-v2 2>$null
$ErrorActionPreference = "Stop"

$kvArgs = @()
foreach ($line in Get-Content ".dev.env") {
    $line = $line.Trim()
    if ($line -eq "" -or $line.StartsWith("#") -or $line -notmatch "=") { continue }
    if ($line -match "^(HOST|PORT|HOST2|PORT2|PYTHONPATH)=") { continue }
    $parts = $line -split "=", 2
    $kvArgs += "$($parts[0].Trim())=$($parts[1].Trim())"
}
if ($kvArgs.Count -gt 0) {
    vault kv put $SecretPath @kvArgs | Out-Null
    Write-Host "   Seeded $($kvArgs.Count) secret(s) to '$SecretPath'" -ForegroundColor DarkGray
}

Write-Host "-> Writing Vault policy..." -ForegroundColor Cyan
'path "secret/data/python-project/*" { capabilities = ["read"] }' |
    vault policy write python-project-policy -

Write-Host "-> Configuring Kubernetes auth..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
vault auth enable kubernetes 2>$null
$ErrorActionPreference = "Stop"

$ErrorActionPreference = "Continue"
$cfgOut = kubectl exec -n $Namespace $vaultPod -- `
    sh -c 'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc.cluster.local"' 2>&1
$cfgRc = $LASTEXITCODE
$ErrorActionPreference = "Stop"

if ($cfgRc -ne 0) {
    Write-Error "Failed to configure Kubernetes auth: $cfgOut"
    exit 1
}
Write-Host "   $cfgOut" -ForegroundColor DarkGray

Write-Host "-> Creating auth role..." -ForegroundColor Cyan
vault write auth/kubernetes/role/python-project `
    bound_service_account_names="python-project,default" `
    bound_service_account_namespaces="default,dev" `
    policies=python-project-policy `
    ttl=1h

Write-Host ""
Write-Host "Vault is running in k3d" -ForegroundColor Green
Write-Host "   UI      : http://localhost:$LocalPort/ui  (token: $RootToken)"
Write-Host "   Secrets : vault kv get $SecretPath"
Write-Host "   Verify  : kubectl exec -n $Namespace $vaultPod -- sh -c 'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read auth/kubernetes/config'"