#!/usr/bin/env pwsh
# scripts/k8s-apply-secrets.ps1
# Reads .dev.env and creates/updates a Kubernetes Secret named python-project-secrets.
# Never commits actual secret values — this script is the bridge.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$EnvFile    = ".dev.env"
$SecretName = "python-project-secrets"

if (-not (Test-Path $EnvFile)) {
    Write-Error "Missing $EnvFile — cannot create k8s secret."
    exit 1
}

# Parse key=value lines, skip comments and blanks
$literals = Get-Content $EnvFile | Where-Object {
    $_ -match "^\s*[^#\s].*=.*"
} | ForEach-Object {
    $parts = $_ -split "=", 2
    "--from-literal=$($parts[0].Trim())=$($parts[1].Trim())"
}

if (-not $literals) {
    Write-Warning "No variables found in $EnvFile."
    exit 0
}

# kubectl create secret (replace if exists)
$cmd = @("create", "secret", "generic", $SecretName) + $literals + @("--dry-run=client", "-o", "yaml")
kubectl @cmd | kubectl apply -f -

Write-Host "✓ Secret '$SecretName' applied." -ForegroundColor Green
