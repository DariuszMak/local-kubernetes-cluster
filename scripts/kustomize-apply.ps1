#!/usr/bin/env pwsh

param(
    [ValidateSet("dev", "staging", "prod", "app2-dev", "app2-staging", "app2-prod")]
    [string]$Overlay = "dev",

    [switch]$DryRun,

    [switch]$SkipValidate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$OverlayPath = "k8s/kustomize/overlays/$Overlay"

$Namespace = switch -Regex ($Overlay) {
    "staging$" { "staging" }
    "prod$"    { "prod" }
    default    { "dev" }
}

powershell -ExecutionPolicy Bypass -File scripts/render-secrets.ps1 -Overlay $Overlay

if (-not $SkipValidate) {
    powershell -ExecutionPolicy Bypass -File scripts/kubeconform-validate.ps1 -Overlays $Overlay
}

$ErrorActionPreference = "Continue"
$nsExists = kubectl get namespace $Namespace 2>$null
$ErrorActionPreference = "Stop"
if (-not $nsExists) {
    Write-Host "-> Creating namespace '$Namespace'..." -ForegroundColor Cyan
    kubectl create namespace $Namespace
}

if ($DryRun) {
    Write-Host "-> Diff for overlay '$Overlay' (dry-run)..." -ForegroundColor Cyan
    kubectl diff -k $OverlayPath
} else {
    Write-Host "-> Applying overlay '$Overlay'..." -ForegroundColor Cyan
    kubectl apply -k $OverlayPath
    Write-Host ""
    Write-Host "Done! Overlay '$Overlay' applied." -ForegroundColor Green
    Write-Host "   kubectl get all -n $Namespace"
}
