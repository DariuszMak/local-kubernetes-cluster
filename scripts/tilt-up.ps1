#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Starts the k3d cluster (if needed) then launches Tilt.
    Tilt itself watches files and handles image build + Helm deploy.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ClusterName = "python-project"
$K3dConfig   = "k8s/k3d-config.yaml"

$ErrorActionPreference = "Continue"
$clusterExists = k3d cluster list --no-headers 2>$null | Select-String $ClusterName
$ErrorActionPreference = "Stop"

if (-not $clusterExists) {
    Write-Host "-> Creating k3d cluster from $K3dConfig ..." -ForegroundColor Cyan
    k3d cluster create --config $K3dConfig
} else {
    Write-Host "v Cluster '$ClusterName' already exists, starting if stopped..." -ForegroundColor Green
    $ErrorActionPreference = "Continue"
    k3d cluster start $ClusterName 2>$null
    $ErrorActionPreference = "Stop"
}

Write-Host "-> Merging kubeconfig..." -ForegroundColor Cyan
k3d kubeconfig merge $ClusterName --kubeconfig-merge-default
kubectl config use-context "k3d-$ClusterName"

$ErrorActionPreference = "Continue"
$currentServer = kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}" 2>$null
$ErrorActionPreference = "Stop"
if ($currentServer -match "host\.docker\.internal:(\d+)") {
    $port      = $Matches[1]
    $newServer = "https://127.0.0.1:$port"
    Write-Host "   Rewriting $currentServer -> $newServer" -ForegroundColor DarkGray
    kubectl config set-cluster "k3d-$ClusterName" --server=$newServer
}

$ErrorActionPreference = "Continue"
$ingressNs = kubectl get ns ingress-nginx --ignore-not-found 2>$null
$ErrorActionPreference = "Stop"
if (-not $ingressNs) {
    Write-Host "-> Installing ingress-nginx..." -ForegroundColor Cyan
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/cloud/deploy.yaml
    kubectl wait --namespace ingress-nginx `
        --for=condition=ready pod `
        --selector=app.kubernetes.io/component=controller `
        --timeout=120s
} else {
    Write-Host "v ingress-nginx already present." -ForegroundColor Green
}

Write-Host ""
Write-Host "-> Starting Tilt..." -ForegroundColor Cyan
Write-Host "   App (port-forward) : http://localhost:8001"
Write-Host "   Tilt UI             : http://localhost:10350"
Write-Host ""

tilt up