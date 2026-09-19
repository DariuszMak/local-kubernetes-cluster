#!/usr/bin/env pwsh

param(
    [string[]]$Overlays = @("dev", "staging", "prod", "app2-dev", "app2-staging", "app2-prod"),

    [string]$KubernetesVersion = "1.31.0",

    [string]$SchemaLocation = "https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command kubeconform -ErrorAction SilentlyContinue)) {
    Write-Error "kubeconform not found. Install from https://github.com/yannh/kubeconform/releases"
    exit 1
}

if (-not (Get-Command kustomize -ErrorAction SilentlyContinue)) {
    Write-Error "kustomize not found. Install from https://kubectl.docs.kubernetes.io/installation/kustomize/"
    exit 1
}

$failed = @()

foreach ($overlay in $Overlays) {
    $path = "k8s/kustomize/overlays/$overlay"

    if (-not (Test-Path $path)) {
        Write-Warning "Skipping missing overlay: $path"
        continue
    }

    Write-Host "-> Validating overlay '$overlay'..." -ForegroundColor Cyan

    $ErrorActionPreference = "Continue"
    $rendered = kustomize build $path 2>&1
    $buildRc = $LASTEXITCODE
    $ErrorActionPreference = "Stop"

    if ($buildRc -ne 0) {
        Write-Host $rendered -ForegroundColor Red
        $failed += "$overlay (kustomize build)"
        continue
    }

    $ErrorActionPreference = "Continue"
    $rendered | kubeconform `
        -strict `
        -summary `
        -ignore-missing-schemas `
        -kubernetes-version $KubernetesVersion `
        -schema-location default `
        -schema-location $SchemaLocation `
        -
    $confRc = $LASTEXITCODE
    $ErrorActionPreference = "Stop"

    if ($confRc -ne 0) {
        $failed += "$overlay (kubeconform)"
    } else {
        Write-Host "   OK" -ForegroundColor Green
    }
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Error "Validation failed for: $($failed -join ', ')"
    exit 1
}

Write-Host ""
Write-Host "All overlays valid." -ForegroundColor Green
