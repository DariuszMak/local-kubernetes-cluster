#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Registry  = "localhost:5001"
$ImageName = "$Registry/python-project:local"

Write-Host "Rebuilding image..." -ForegroundColor Cyan
docker build -t $ImageName .

Write-Host "Pushing to local registry..." -ForegroundColor Cyan
docker push $ImageName

Write-Host "Restarting deployment..." -ForegroundColor Cyan
kubectl rollout restart deployment/python-project
kubectl rollout status deployment/python-project --timeout=60s

Write-Host "Redeployed. http://localhost:8082" -ForegroundColor Green
