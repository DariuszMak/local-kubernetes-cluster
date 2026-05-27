#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start a local Vault dev server and seed it with secrets from .dev.env.
    Vault runs in dev mode: in-memory, auto-unsealed, no TLS - fully local.

.NOTES
    Root token is fixed to "root" for local dev convenience.
    Never use dev mode in production.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VaultAddr  = "http://127.0.0.1:8200"
$RootToken  = "root"
$SecretPath = "secret/python-project/dev"
$DevEnvFile = ".dev.env"

# -- 1. Check vault binary ----------------------------------------------------
if (-not (Get-Command vault -ErrorAction SilentlyContinue)) {
    Write-Error "vault binary not found. Install from https://developer.hashicorp.com/vault/install"
    exit 1
}

# -- 2. Kill any existing vault dev server -----------------------------------
$existing = Get-Process -Name "vault" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "-> Stopping existing Vault process(es)..." -ForegroundColor Yellow
    $existing | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# -- 3. Start vault dev server in background ---------------------------------
Write-Host "-> Starting Vault dev server on $VaultAddr ..." -ForegroundColor Cyan
$vaultProc = Start-Process vault `
    -ArgumentList "server", "-dev", "-dev-root-token-id=$RootToken", "-dev-listen-address=127.0.0.1:8200" `
    -PassThru -WindowStyle Hidden
Write-Host "   PID: $($vaultProc.Id)" -ForegroundColor DarkGray

# Wait for Vault to be ready
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

# -- 4. Enable KV v2 at 'secret/' (already enabled in dev mode, just confirm) -
$ErrorActionPreference = "Continue"
vault secrets enable -path=secret kv-v2 2>$null
$ErrorActionPreference = "Stop"

# -- 5. Parse .dev.env and write secrets to Vault ----------------------------
if (-not (Test-Path $DevEnvFile)) {
    Write-Warning "$DevEnvFile not found - skipping secret seeding."
} else {
    Write-Host "-> Seeding secrets from $DevEnvFile into Vault path '$SecretPath' ..." -ForegroundColor Cyan

    $kvArgs = @()
    foreach ($line in Get-Content $DevEnvFile) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#") -or $line -notmatch "=") { continue }
        # Skip infra vars that aren't real secrets
        if ($line -match "^(HOST|PORT|PYTHONPATH)=") { continue }
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

# -- 6. Print summary ---------------------------------------------------------
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
