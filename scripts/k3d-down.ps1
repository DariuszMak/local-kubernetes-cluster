#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ClusterName = "python-project"

Write-Host "→ Deleting k3d cluster '$ClusterName'..." -ForegroundColor Yellow
k3d cluster delete $ClusterName

Write-Host "Cluster deleted." -ForegroundColor Green
