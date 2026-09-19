#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ClusterName = "python-project"
$ReleaseName = "python-project"

Write-Host "-> Uninstalling Helm release '$ReleaseName'..." -ForegroundColor Yellow
$ErrorActionPreference = "Continue"
helm uninstall $ReleaseName 2>$null
$ErrorActionPreference = "Stop"

Write-Host "-> Deleting k3d cluster '$ClusterName'..." -ForegroundColor Yellow
k3d cluster delete $ClusterName

Write-Host "Done." -ForegroundColor Green
