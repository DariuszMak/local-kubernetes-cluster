#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Registry   = "localhost:5001"
$ImageName  = "$Registry/python-project:local"
$ImageName2 = "$Registry/python-project-app2:local"

Write-Host "-> Rebuilding images..." -ForegroundColor Cyan
docker build -t $ImageName .
docker push $ImageName

docker build -t $ImageName2 -f Dockerfile.app2 .
docker push $ImageName2

Write-Host "-> Reapplying dev overlays..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File scripts/kustomize-apply.ps1 -Overlay dev
powershell -ExecutionPolicy Bypass -File scripts/kustomize-apply.ps1 -Overlay app2-dev

Write-Host "-> Restarting deployments..." -ForegroundColor Cyan
kubectl rollout restart deployment/dev-python-project -n dev
kubectl rollout restart deployment/app2-dev-python-project-app2 -n dev

kubectl rollout status deployment/dev-python-project -n dev --timeout=120s
kubectl rollout status deployment/app2-dev-python-project-app2 -n dev --timeout=120s

Write-Host ""
Write-Host "Redeploy complete." -ForegroundColor Green
