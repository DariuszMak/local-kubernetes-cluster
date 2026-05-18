#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Registry    = "localhost:5001"
$ImageName   = "$Registry/python-project:local"
$HelmChart   = "helm"
$ReleaseName = "python-project"

# Must match the keys declared under .secrets in values.yaml
$SecretKeys  = @("EXAMPLE_VARIABLE_NAME")

Write-Host "-> Rebuilding image..." -ForegroundColor Cyan
docker build -t $ImageName .

Write-Host "-> Pushing to local registry..." -ForegroundColor Cyan
docker push $ImageName

# Read secret values from .dev.env
$envMap = @{}
foreach ($line in Get-Content ".dev.env") {
    $line = $line.Trim()
    if ($line -eq "" -or $line.StartsWith("#") -or $line -notmatch "=") { continue }
    $parts           = $line -split "=", 2
    $envMap[$parts[0].Trim()] = $parts[1].Trim()
}

$secretArgs = @()
foreach ($key in $SecretKeys) {
    if ($envMap.ContainsKey($key)) {
        $secretArgs += "--set=secrets.$key=$($envMap[$key])"
    } else {
        Write-Warning "Secret key '$key' not found in .dev.env"
    }
}

Write-Host "-> Upgrading Helm release..." -ForegroundColor Cyan
helm upgrade --install $ReleaseName $HelmChart `
    --wait --timeout 60s `
    @secretArgs

Write-Host "Redeployed. http://localhost:8082" -ForegroundColor Green
Write-Host "   helm history $ReleaseName  — to see all releases"