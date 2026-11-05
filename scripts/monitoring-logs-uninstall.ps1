#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Namespace = "monitoring"

Write-Host "-> Uninstalling Loki..." -ForegroundColor Yellow
helm uninstall loki -n $Namespace 2>$null

Write-Host "-> Uninstalling OpenTelemetry Collector..." -ForegroundColor Yellow
helm uninstall otelcol -n $Namespace 2>$null

Write-Host "-> Removing Grafana provisioning config..." -ForegroundColor Yellow
kubectl delete configmap grafana-datasources -n $Namespace 2>$null

Write-Host "-> Restarting Grafana..." -ForegroundColor Yellow
kubectl rollout restart deployment -l app.kubernetes.io/name=grafana -n $Namespace 2>$null

Write-Host "Done." -ForegroundColor Green
