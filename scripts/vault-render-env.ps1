#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fetch secrets from the local Vault dev server and write them to a
    temporary .vault-secrets.env file that the application reads on startup.

.NOTES
    This replaces direct .dev.env secret usage for the running application.
    The generated file is gitignored and regenerated on every run.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VaultAddr   = if ($env:VAULT_ADDR)  { $env:VAULT_ADDR }  else { "http://127.0.0.1:8200" }
$VaultToken  = if ($env:VAULT_TOKEN) { $env:VAULT_TOKEN } else { "root" }
$SecretPath  = "secret/python-project/dev"
$OutFile     = ".vault-secrets.env"

if (-not (Get-Command vault -ErrorAction SilentlyContinue)) {
    Write-Error "vault binary not found."
    exit 1
}

$env:VAULT_ADDR  = $VaultAddr
$env:VAULT_TOKEN = $VaultToken

Write-Host "-> Fetching secrets from Vault ($SecretPath)..." -ForegroundColor Cyan

# vault kv get -format=json returns the full JSON response
$json = vault kv get -format=json $SecretPath 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to read secrets from Vault. Is the dev server running? (task vault-dev)"
    exit 1
}

$data = ($json | ConvertFrom-Json).data.data

$lines = @()
foreach ($key in $data.PSObject.Properties.Name) {
    $lines += "$key=$($data.$key)"
}

# Also forward HOST/PORT from .dev.env so the app knows where to bind
foreach ($line in Get-Content ".dev.env" -ErrorAction SilentlyContinue) {
    $line = $line.Trim()
    if ($line -match "^(HOST|PORT|PYTHONPATH)=") {
        $lines += $line
    }
}

$lines | Set-Content $OutFile -Encoding UTF8
Write-Host "   Wrote $($data.PSObject.Properties.Name.Count) secret(s) to $OutFile" -ForegroundColor DarkGray
Write-Host "v Done. App will read secrets from $OutFile" -ForegroundColor Green
