#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Namespace   = "monitoring"
$ReleaseName = "kube-prometheus-stack"
$ValuesFile  = "helm/monitoring/values.yaml"

$ErrorActionPreference = "Continue"
kubectl get namespace $Namespace 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "-> Creating namespace '$Namespace'..." -ForegroundColor Cyan
    kubectl create namespace $Namespace
}
$ErrorActionPreference = "Stop"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install $ReleaseName prometheus-community/kube-prometheus-stack `
    --namespace $Namespace `
    --values $ValuesFile `
    --timeout 300s `
    --wait

Write-Host ""
Write-Host "Monitoring stack deployed." -ForegroundColor Green
Write-Host "   Grafana  : http://localhost:8082/grafana  (admin / admin)"
Write-Host "   kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
