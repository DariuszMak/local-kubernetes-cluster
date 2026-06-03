#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Namespace   = "argocd"
$ReleaseName = "argocd"

Write-Host "-> Removing Application manifests..." -ForegroundColor Yellow
$ErrorActionPreference = "Continue"
kubectl delete -f k8s/argocd/ 2>$null
$ErrorActionPreference = "Stop"

Write-Host "-> Uninstalling Argo CD Helm release..." -ForegroundColor Yellow
$ErrorActionPreference = "Continue"
helm uninstall $ReleaseName -n $Namespace 2>$null
kubectl delete namespace $Namespace 2>$null
$ErrorActionPreference = "Stop"

Write-Host "Done." -ForegroundColor Green
