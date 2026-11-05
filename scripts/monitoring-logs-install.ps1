#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Namespace      = "monitoring"
$LokiRelease    = "loki"
$LokiChart      = "grafana/loki"
$LokiValuesFile = "helm/monitoring/loki-values.yaml"
$OTELRelease    = "otelcol"
$OTELChart      = "open-telemetry/opentelemetry-collector"
$OTELValuesFile = "helm/monitoring/otelcol-values.yaml"

Write-Host ""
Write-Host "=== Installing Grafana Loki + OpenTelemetry Collector ===" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Ensure namespace ---
$ErrorActionPreference = "Continue"
kubectl get namespace $Namespace 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "-> Creating namespace '$Namespace'..." -ForegroundColor Cyan
    kubectl create namespace $Namespace
}
$ErrorActionPreference = "Stop"

# --- Step 2: Add Helm repos ---
Write-Host "-> Adding Helm repos..." -ForegroundColor Yellow
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# --- Step 3: Install Loki ---
Write-Host "-> Installing Grafana Loki..." -ForegroundColor Yellow
helm upgrade --install $LokiRelease $LokiChart `\
    --namespace $Namespace `\
    --values $LokiValuesFile `\
    --timeout 300s `\
    --wait

Write-Host "-> Loki installed successfully." -ForegroundColor Green

# --- Step 4: Install OpenTelemetry Collector ---
Write-Host "-> Installing OpenTelemetry Collector..." -ForegroundColor Yellow
helm upgrade --install $OTELRelease $OTELChart `\
    --namespace $Namespace `\
    --values $OTELValuesFile `\
    --timeout 300s `\
    --wait

Write-Host "-> OpenTelemetry Collector installed successfully." -ForegroundColor Green

# --- Step 5: Update Grafana provisioning config ---
Write-Host "-> Updating Grafana provisioning config for Loki datasource..." -ForegroundColor Yellow

# Create provisioning directory if it doesn't exist
$k8sProvisioningDir = "/tmp/grafana-provisioning"
New-Item -ItemType Directory -Force -Path $k8sProvisioningDir | Out-Null

# Copy the provisioning config
$provisioningFile = "helm/monitoring/provisioning/datasources.yaml"
if (Test-Path $provisioningFile) {
    $base64Config = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content $provisioningFile -Raw)))
    
    # Create a ConfigMap from the provisioning config
    $configMapYaml = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: $Namespace
data:
  datasources.yaml: |
$($base64Config -replace '(.{80})', "`$1`n" | ForEach-Object { if ($_ -match '^.{0,80}$') { $PSItem = $_ } })
"@
    
    # Write to temp file and apply
    $configMapFile = Join-Path $k8sProvisioningDir "datasources-configmap.yaml"
    $configMapYaml | Out-File -FilePath $configMapFile -Encoding utf8
    kubectl apply -f $configMapFile
    Remove-Item $configMapFile -Force
    
    Write-Host "-> Grafana provisioning config applied." -ForegroundColor Green
}

# --- Step 6: Restart Grafana to pick up new config ---
Write-Host "-> Restarting Grafana pods..." -ForegroundColor Yellow
kubectl rollout restart deployment -l app.kubernetes.io/name=grafana -n $Namespace
Start-Sleep -Seconds 5

# --- Step 7: Show status ---
Write-Host ""
Write-Host "=== Monitoring Logs Stack Installed ===" -ForegroundColor Green
Write-Host ""
Write-Host "Loki      : http://localhost:3100/loki/api/v1/push" -ForegroundColor Cyan
Write-Host "OTEL gRPC : localhost:4317" -ForegroundColor Cyan
Write-Host "OTEL HTTP : localhost:4318" -ForegroundColor Cyan
Write-Host "OTEL MTRX : localhost:8888" -ForegroundColor Cyan
Write-Host ""
Write-Host "In Grafana (http://localhost:3000/grafana):" -ForegroundColor Yellow
Write-Host "  1. Go to Explore -> select 'Loki' as data source" -ForegroundColor White
Write-Host "  2. Query: {service=~'python-api|python-app2'}" -ForegroundColor White
Write-Host "  3. Look for 'http_request_complete' log entries" -ForegroundColor White
Write-Host ""
Write-Host "To uninstall, run: task monitoring-logs-down" -ForegroundColor Yellow
Write-Host ""
