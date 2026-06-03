#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory)]
    [string]$RepoURL,

    [string]$SshKeyFile = "",

    [ValidateSet("dev", "staging", "prod", "all")]
    [string]$Env = "all"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Namespace = "argocd"

Write-Host "-> Patching repoURL in Application manifests..." -ForegroundColor Cyan

$files = Get-ChildItem "k8s/argocd/app-*.yaml", "k8s/argocd/project.yaml"
foreach ($f in $files) {
    (Get-Content $f.FullName) -replace "https://github.com/DariuszMak/local-kubernetes-cluster", $RepoURL |
        Set-Content $f.FullName
}

if ($SshKeyFile -and (Test-Path $SshKeyFile)) {
    Write-Host "-> Registering repo with SSH key..." -ForegroundColor Cyan
    $sshKey = Get-Content $SshKeyFile -Raw
    $secretManifest = @"
apiVersion: v1
kind: Secret
metadata:
  name: python-project-repo
  namespace: $Namespace
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: $RepoURL
  sshPrivateKey: |
$(($sshKey -split "`n" | ForEach-Object { "    $_" }) -join "`n")
"@
    $secretManifest | kubectl apply -f -
} else {
    Write-Host "-> Registering public repo (no SSH key)..." -ForegroundColor Cyan
    $secretManifest = @"
apiVersion: v1
kind: Secret
metadata:
  name: python-project-repo
  namespace: $Namespace
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: $RepoURL
"@
    $secretManifest | kubectl apply -f -
}

Write-Host "-> Applying AppProject..." -ForegroundColor Cyan
kubectl apply -f k8s/argocd/project.yaml

$appFiles = switch ($Env) {
    "dev"     { @("k8s/argocd/app-dev.yaml") }
    "staging" { @("k8s/argocd/app-staging.yaml") }
    "prod"    { @("k8s/argocd/app-prod.yaml") }
    "all"     { @("k8s/argocd/app-dev.yaml", "k8s/argocd/app-staging.yaml", "k8s/argocd/app-prod.yaml") }
}

Write-Host "-> Applying Application manifests ($Env)..." -ForegroundColor Cyan
foreach ($f in $appFiles) {
    kubectl apply -f $f
}

Write-Host ""
Write-Host "GitOps configured." -ForegroundColor Green
Write-Host "   Argo CD UI : http://localhost:8082/argocd"
Write-Host "   Push to $RepoURL and Argo CD will sync automatically."
