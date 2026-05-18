#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Registry    = "localhost:5001"
$ImageName   = "$Registry/python-project:local"
$HelmChart   = "helm"
$ReleaseName = "python-project"

Write-Host "-> Rebuilding image..." -ForegroundColor Cyan
docker build -t $ImageName .

Write-Host "-> Pushing to local registry..." -ForegroundColor Cyan
docker push $ImageName

Write-Host "-> Upgrading Helm release..." -ForegroundColor Cyan

$secretArgs = @()
foreach ($line in Get-Content ".dev.env") {
    $line = $line.Trim()
    if ($line -eq "" -or $line.StartsWith("#") -or $line -notmatch "=") { continue }
    $parts = $line -split "=", 2
    $key   = $parts[0].Trim()
    $value = $parts[1].Trim()
    $secretArgs += "--set=secrets.$key=$value"
}

helm upgrade --install $ReleaseName $HelmChart `
    --wait --timeout 60s `
    @secretArgs

Write-Host "Redeployed. http://localhost:8082" -ForegroundColor Green
Write-Host "   helm history $ReleaseName  — to see all releases"
