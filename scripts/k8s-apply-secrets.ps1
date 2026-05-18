#!/usr/bin/env pwsh

$EnvFile    = ".dev.env"
$SecretName = "python-project-secrets"

if (-not (Test-Path $EnvFile)) {
    Write-Error "Missing $EnvFile - cannot create k8s secret."
    exit 1
}

$literals = @()
foreach ($line in Get-Content $EnvFile) {
    $line = $line.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }
    if ($line -notmatch "=") { continue }
    $parts = $line -split "=", 2
    $key   = $parts[0].Trim()
    $value = $parts[1].Trim()
    $literals += "--from-literal=$key=$value"
}

if ($literals.Count -eq 0) {
    Write-Warning "No variables found in $EnvFile."
    exit 0
}

$cmd = @("create", "secret", "generic", $SecretName) + $literals + @("--dry-run=client", "-o", "yaml")
kubectl @cmd | kubectl apply -f -

Write-Host "v Secret '$SecretName' applied." -ForegroundColor Green