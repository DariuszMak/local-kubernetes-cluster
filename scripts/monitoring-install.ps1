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


$POD_NAME = kubectl --namespace monitoring get pod `
  -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=kube-prometheus-stack" `
  -o jsonpath="{.items[0].metadata.name}"
  
  
Start-Job -ScriptBlock {
    kubectl --namespace monitoring port-forward $using:POD_NAME 3000:3000
}


$encoded = kubectl get secret --namespace monitoring `
  -l app.kubernetes.io/component=admin-secret `
  -o jsonpath="{.items[0].data.admin-password}"

[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded))

Start-Process "http://localhost:3000/grafana/" ; 