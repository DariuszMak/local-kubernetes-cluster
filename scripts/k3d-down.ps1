#!/usr/bin/env pwsh
# scripts/k3d-down.ps1
# Stops and deletes the k3d cluster (does NOT remove the local registry image cache).

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ClusterName = "python-project"

Write-Host "→ Deleting k3d cluster '$ClusterName'..." -ForegroundColor Yellow
k3d cluster delete $ClusterName

Write-Host "✅ Cluster deleted." -ForegroundColor Green
