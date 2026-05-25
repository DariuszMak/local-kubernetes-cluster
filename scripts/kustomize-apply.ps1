#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Apply a Kustomize overlay to the current kubectl context.

.PARAMETER Overlay
    Which overlay to apply: dev | staging | prod  (default: dev)

.PARAMETER DryRun
    Pass -DryRun to preview without applying (runs kubectl diff).

.EXAMPLE
    .\scripts\kustomize-apply.ps1 -Overlay dev
    .\scripts\kustomize-apply.ps1 -Overlay prod -DryRun
#>
param(
    [ValidateSet("dev", "staging", "prod")]
    [string]$Overlay = "dev",

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$OverlayPath = "k8s/kustomize/overlays/$Overlay"
$SecretsEnv  = "$OverlayPath/.$Overlay.secrets.env"
$ExampleEnv  = "$OverlayPath/.$Overlay.secrets.env.example"

if ($Overlay -eq "dev" -and -not (Test-Path $SecretsEnv)) {
    if (Test-Path $ExampleEnv) {
        Write-Host "-> Secrets file not found. Copying example to $SecretsEnv ..." -ForegroundColor Yellow
        Copy-Item $ExampleEnv $SecretsEnv
        Write-Host "   Edit $SecretsEnv with real values if needed." -ForegroundColor DarkGray
    } else {
        Write-Host "-> Generating $SecretsEnv from .dev.env ..." -ForegroundColor Yellow
        $lines = Get-Content ".dev.env" | Where-Object { $_ -notmatch "^#" -and $_ -match "=" }
        $lines | Set-Content $SecretsEnv
    }
}

$ErrorActionPreference = "Continue"
$nsExists = kubectl get namespace $Overlay 2>$null
$ErrorActionPreference = "Stop"
if (-not $nsExists) {
    Write-Host "-> Creating namespace '$Overlay'..." -ForegroundColor Cyan
    kubectl create namespace $Overlay
}

if ($DryRun) {
    Write-Host "-> Diff for overlay '$Overlay' (dry-run)..." -ForegroundColor Cyan
    kubectl diff -k $OverlayPath
} else {
    Write-Host "-> Applying overlay '$Overlay'..." -ForegroundColor Cyan
    kubectl apply -k $OverlayPath
    Write-Host ""
    Write-Host "Done! Overlay '$Overlay' applied." -ForegroundColor Green
    Write-Host "   kubectl get all -n $Overlay"
}
