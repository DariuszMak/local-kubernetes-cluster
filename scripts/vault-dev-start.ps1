#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VaultAddr  = "http://127.0.0.1:8200"
$RootToken  = "root"
$SecretPath = "secret/python-project/dev"
$DevEnvFile = ".dev.env"

if (-not (Get-Command vault -ErrorAction SilentlyContinue)) {
    Write-Error "vault binary not found. Install from https://developer.hashicorp.com/vault/install"
    exit 1
}

$existing = Get-Process -Name "vault" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "-> Stopping existing Vault process(es)..." -ForegroundColor Yellow
    $existing | Stop-Process -Force
    Start-Sleep -Seconds 1
}

Write-Host "-> Starting Vault dev server on $VaultAddr ..." -ForegroundColor Cyan
$vaultProc = Start-Process vault `
    -ArgumentList "server", "-dev", "-dev-root-token-id=$RootToken", "-dev-listen-address=127.0.0.1:8200" `
    -PassThru -WindowStyle Hidden
Write-Host "   PID: $($vaultProc.Id)" -ForegroundColor DarkGray

$ready = $false
$retries = 0
$env:VAULT_ADDR  = $VaultAddr
$env:VAULT_TOKEN = $RootToken
while (-not $ready) {
    $retries++
    if ($retries -gt 20) { Write-Error "Vault did not start in time."; exit 1 }
    Start-Sleep -Milliseconds 500
    $ErrorActionPreference = "Continue"
    $status = vault status 2>&1
    $ErrorActionPreference = "Stop"
    if ($LASTEXITCODE -eq 0 -or ($status -match "Initialized\s+true")) {
        $ready = $true
    }
}
Write-Host "v Vault is ready." -ForegroundColor Green

$ErrorActionPreference = "Continue"
vault secrets enable -path=secret kv-v2 2>$null
$ErrorActionPreference = "Stop"

if (-not (Test-Path $DevEnvFile)) {
    Write-Warning "$DevEnvFile not found - skipping secret seeding."
} else {
    Write-Host "-> Seeding secrets from $DevEnvFile into Vault path '$SecretPath' ..." -ForegroundColor Cyan

    $kvArgs = @()
    foreach ($line in Get-Content $DevEnvFile) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#") -or $line -notmatch "=") { continue }
        if ($line -match "^(HOST|PORT|HOST2|PORT2|PYTHONPATH)=") { continue }
        $parts = $line -split "=", 2
        $kvArgs += "$($parts[0].Trim())=$($parts[1].Trim())"
    }

    if ($kvArgs.Count -gt 0) {
        vault kv put $SecretPath @kvArgs
        Write-Host "   Wrote $($kvArgs.Count) secret(s) to $SecretPath" -ForegroundColor DarkGray
    } else {
        Write-Host "   No secret vars found in $DevEnvFile" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Vault dev server running" -ForegroundColor Green
Write-Host "   Address : $VaultAddr"
Write-Host "   Token   : $RootToken"
Write-Host "   UI      : $VaultAddr/ui"
Write-Host "   Secrets : vault kv get $SecretPath"
Write-Host ""
Write-Host "Environment vars for your shell:"
Write-Host "   `$env:VAULT_ADDR  = '$VaultAddr'"
Write-Host "   `$env:VAULT_TOKEN = '$RootToken'"

Start-Process "http://127.0.0.1:8200/ui" ; 
