#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "-> Tearing down Tilt resources..." -ForegroundColor Yellow
tilt down

Write-Host "-> Deleting k3d cluster..." -ForegroundColor Yellow
k3d cluster delete python-project

Write-Host "Done." -ForegroundColor Green
