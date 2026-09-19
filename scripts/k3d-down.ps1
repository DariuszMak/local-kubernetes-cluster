#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ClusterName = "python-project"

Write-Host "-> Deleting dev overlays..." -ForegroundColor Yellow
$ErrorActionPreference = "Continue"
kubectl delete -k k8s/kustomize/overlays/app2-dev 2>$null
kubectl delete -k k8s/kustomize/overlays/dev 2>$null
$ErrorActionPreference = "Stop"

Write-Host "-> Deleting k3d cluster '$ClusterName'..." -ForegroundColor Yellow
$ErrorActionPreference = "Continue"
k3d cluster delete $ClusterName 2>$null
$ErrorActionPreference = "Stop"

Write-Host "Done." -ForegroundColor Green
