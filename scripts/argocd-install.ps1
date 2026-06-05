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
Write-Host "-> Waiting for argocd-server pod..." -ForegroundColor Cyan
kubectl wait --namespace $Namespace `
    --for=condition=ready pod `
    --selector=app.kubernetes.io/name=argocd-server `
    --timeout=120s

$password = "admin123"

Write-Host ""
Write-Host "Argo CD deployed." -ForegroundColor Green
Write-Host "   UI via redirect : http://localhost:8082/argocd"
Write-Host "   login           : admin"
Write-Host "   password        : $password" -ForegroundColor Yellow

Start-Process kubectl `
    -ArgumentList "port-forward", "svc/argocd-server", "-n", $Namespace, "8080:80" `
    -WindowStyle Hidden

Start-Sleep -Seconds 2
Start-Process "http://localhost:8080/argocd"