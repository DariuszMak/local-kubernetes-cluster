#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VaultAddr  = if ($env:VAULT_ADDR)  { $env:VAULT_ADDR }  else { "http://127.0.0.1:8200" }
$VaultToken = if ($env:VAULT_TOKEN) { $env:VAULT_TOKEN } else { "root" }
$SecretPath = "secret/python-project/dev"
$OutFile    = ".vault-secrets.env"

if (-not (Get-Command vault -ErrorAction SilentlyContinue)) {
    Write-Error "vault binary not found."
    exit 1
}

$env:VAULT_ADDR  = $VaultAddr
$env:VAULT_TOKEN = $VaultToken


function Wait-VaultReady {
    param(
        [string]$Url = $VaultAddr,
        [int]$TimeoutSec = 120
    )

    Write-Host "-> Waiting for Vault at $Url ..." -ForegroundColor Cyan

    $start = Get-Date

    while ((Get-Date) - $start -lt (New-TimeSpan -Seconds $TimeoutSec)) {
        try {
            $resp = Invoke-WebRequest "$Url/v1/sys/health" -UseBasicParsing -TimeoutSec 2

            # Vault zwraca:
            # 200 = ok
            # 429/472/473 też oznaczają działający vault (sealed/uninitialized states)
            if ($resp.StatusCode -in 200, 429, 472, 473) {
                Write-Host "-> Vault is ready." -ForegroundColor Green
                return $true
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }

    return $false
}


if (-not (Wait-VaultReady)) {
    Write-Error "Vault is not ready after timeout (30s)."
    exit 1
}


Write-Host "-> Fetching secrets from Vault ($SecretPath)..." -ForegroundColor Cyan

try {
    $jsonString = vault kv get -format=json $SecretPath 2>&1
} catch {
    Write-Error "Failed to execute vault CLI."
    exit 1
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to read secrets from Vault. Is the dev server running? (task vault-dev)"
    exit 1
}

$parsed = $jsonString | ConvertFrom-Json

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

$lines = [System.Collections.Generic.List[string]]::new()

$props = @($secretData.PSObject.Properties)
foreach ($prop in $props) {
    $lines.Add("$($prop.Name)=$($prop.Value)")
}

# merge dev env overrides
foreach ($line in (Get-Content ".dev.env" -ErrorAction SilentlyContinue)) {
    $line = $line.Trim()
    if ($line -match "^(HOST|PORT|PYTHONPATH)=") {
        $lines.Add($line)
    }
}

$lines | Set-Content $OutFile -Encoding UTF8

Write-Host "   Wrote $($props.Count) secret(s) to $OutFile" -ForegroundColor DarkGray
Write-Host "v Done. App will read secrets from $OutFile" -ForegroundColor Green
