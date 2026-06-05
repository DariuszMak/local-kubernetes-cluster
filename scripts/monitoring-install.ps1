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
  
  
Start-Process -NoNewWindow -FilePath "kubectl" -ArgumentList @(
    "--namespace", "monitoring",
    "port-forward",
    "svc/kube-prometheus-stack-grafana",
    "3000:80"
)

$encoded = kubectl get secret --namespace monitoring `
  -l app.kubernetes.io/component=admin-secret `
  -o jsonpath="{.items[0].data.admin-password}"

[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded))

$password = (kubectl get secret --namespace monitoring `
    kube-prometheus-stack-grafana `
    -o jsonpath="{.data.admin-password}") |
    ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "Grafana password: $password" -ForegroundColor Yellow

Start-Process -NoNewWindow -FilePath "kubectl" -ArgumentList @(
    "--namespace", "monitoring",
    "port-forward",
    "svc/kube-prometheus-stack-grafana",
    "3000:80"
)

Start-Sleep -Seconds 2
Start-Process "http://localhost:3000/grafana/login"
Write-Host "   Login: admin / $password" -ForegroundColor Yellow
