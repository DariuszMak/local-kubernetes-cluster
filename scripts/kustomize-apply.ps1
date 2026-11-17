#!/usr/bin/env pwsh

param(
    [ValidateSet("dev")]
    [string]$Overlay = "dev",

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$OverlayNames = @("app-$Overlay", "app2-$Overlay")

foreach ($OverlayName in $OverlayNames) {
    $OverlayPath = "k8s/kustomize/overlays/$OverlayName"
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
}

$ErrorActionPreference = "Continue"
$nsExists = kubectl get namespace $Overlay 2>$null
$ErrorActionPreference = "Stop"
if (-not $nsExists) {
    Write-Host "-> Creating namespace '$Overlay'..." -ForegroundColor Cyan
    kubectl create namespace $Overlay
}

foreach ($OverlayName in $OverlayNames) {
    $OverlayPath = "k8s/kustomize/overlays/$OverlayName"

    if ($DryRun) {
        Write-Host "-> Diff for overlay '$OverlayName' (dry-run)..." -ForegroundColor Cyan
        kubectl diff -k $OverlayPath
    } else {
        Write-Host "-> Applying overlay '$OverlayName'..." -ForegroundColor Cyan
        kubectl apply -k $OverlayPath
        Write-Host "   Overlay '$OverlayName' applied." -ForegroundColor Green
    }
}

if (-not $DryRun) {
    Write-Host ""
    Write-Host "Done! Overlays applied: $($OverlayNames -join ', ')" -ForegroundColor Green
    Write-Host "   kubectl get all -n $Overlay"
}
