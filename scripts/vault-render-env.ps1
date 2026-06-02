#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------
# Config
# -----------------------------
$vaultHost = if ($env:VAULT_HOST) { $env:VAULT_HOST } else { "127.0.0.1" }
$vaultPort = if ($env:VAULT_PORT) { $env:VAULT_PORT } else { 8200 }

$VaultAddr  = if ($env:VAULT_ADDR)  { $env:VAULT_ADDR }  else { "http://$vaultHost`:$vaultPort" }
$VaultToken = if ($env:VAULT_TOKEN) { $env:VAULT_TOKEN } else { "root" }

$SecretPath = "secret/python-project/dev"
$OutFile    = ".vault-secrets.env"

# -----------------------------
# Preconditions
# -----------------------------
if (-not (Get-Command vault -ErrorAction SilentlyContinue)) {
    Write-Error "vault binary not found."
    exit 1
}

$env:VAULT_ADDR  = $VaultAddr
$env:VAULT_TOKEN = $VaultToken

# -----------------------------
# Wait for Vault
# -----------------------------
function Wait-VaultReady {
    param(
        [string]$Url,
        [int]$TimeoutSec = 180
    )

    Write-Host "-> Waiting for Vault at $Url ..." -ForegroundColor Cyan

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {

        try {
            $resp = Invoke-WebRequest "$Url/v1/sys/health" `
                -TimeoutSec 3 `
                -UseBasicParsing `
                -ErrorAction Stop

            if ($resp.StatusCode -in 200, 429, 472, 473) {
                Write-Host "-> Vault is ready." -ForegroundColor Green
                return $true
            }
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }

    return $false
}

if (-not (Wait-VaultReady -Url $VaultAddr)) {
    Write-Error "Vault is not ready after timeout (180s)."
    exit 1
}

# -----------------------------
# Fetch secrets
# -----------------------------
Write-Host "-> Fetching secrets from Vault ($SecretPath)..." -ForegroundColor Cyan

$jsonString = vault kv get -format=json $SecretPath 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to read secrets from Vault. Is the dev server running?"
    exit 1
}

$parsed = $jsonString | ConvertFrom-Json

# KV v2 vs v1 handling
$secretData = $null

if ($parsed.data.PSObject.Properties.Name -contains "data") {
    $secretData = $parsed.data.data   # KV v2
} else {
    $secretData = $parsed.data        # KV v1
}

if ($null -eq $secretData) {
    Write-Error "Could not find secret data in Vault response. Check path '$SecretPath'."
    exit 1
}

# -----------------------------
# Build env file
# -----------------------------
$lines = [System.Collections.Generic.List[string]]::new()

foreach ($prop in $secretData.PSObject.Properties) {
    $lines.Add("$($prop.Name)=$($prop.Value)")
}

# Merge dev overrides
$devEnvPath = ".dev.env"

if (Test-Path $devEnvPath) {
    foreach ($line in Get-Content $devEnvPath) {
        $line = $line.Trim()

        if ($line -match "^(HOST|PORT|PYTHONPATH)=") {
            $lines.Add($line)
        }
    }
}

$lines | Set-Content $OutFile -Encoding UTF8

$secretCount = @($secretData.PSObject.Properties).Count
Write-Host "-> Wrote $secretCount secret(s) to $OutFile" -ForegroundColor DarkGray

Write-Host "[OK] Done. App will read secrets from $OutFile" -ForegroundColor Green
