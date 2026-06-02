#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Namespace   = "monitoring"
$ReleaseName = "kube-prometheus-stack"

Write-Host "-> Uninstalling '$ReleaseName'..." -ForegroundColor Yellow
$ErrorActionPreference = "Continue"
helm uninstall $ReleaseName -n $Namespace 2>$null

kubectl delete namespace $Namespace 2>$null
$ErrorActionPreference = "Stop"

Write-Host "Done." -ForegroundColor Green
