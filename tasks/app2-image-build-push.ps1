#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Registry  = "localhost:5001"
$ImageName = "$Registry/python-project-app2:local"

Write-Host "-> Building Docker image: $ImageName ..." -ForegroundColor Cyan
docker build -t $ImageName -f Dockerfile.app2 .

Write-Host "-> Pushing image to local registry..." -ForegroundColor Cyan
docker push $ImageName

Write-Host ""
Write-Host "Done. Image pushed: $ImageName" -ForegroundColor Green
