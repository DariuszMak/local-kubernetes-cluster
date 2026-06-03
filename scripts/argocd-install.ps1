#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Namespace   = "argocd"
$ReleaseName = "argocd"
$ValuesFile  = "helm/argocd/values.yaml"

$ErrorActionPreference = "Continue"
kubectl get namespace $Namespace 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "-> Creating namespace '$Namespace'..." -ForegroundColor Cyan
    kubectl create namespace $Namespace
}
$ErrorActionPreference = "Stop"

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install $ReleaseName argo/argo-cd `
    --namespace $Namespace `
    --values $ValuesFile `
    --timeout 300s `
    --wait

Write-Host ""
Write-Host "Argo CD deployed." -ForegroundColor Green
Write-Host "   UI : http://localhost:8082/argocd"
Write-Host ""

$encoded = kubectl get secret argocd-initial-admin-secret -n $Namespace `
    -o jsonpath="{.data.password}" 2>$null

if ($encoded) {
    $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded))
    Write-Host "   admin password : $password" -ForegroundColor Yellow
    Write-Host "   (change it after first login)" -ForegroundColor DarkGray
}
