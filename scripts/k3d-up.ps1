#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$ClusterName  = "python-project"
$Registry     = "localhost:5001"
$ImageName    = "$Registry/python-project:local"
$K3dConfig    = "k8s/k3d-config.yaml"
$K8sManifests = "k8s"

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

Write-Host "-> Merging kubeconfig for k3d-$ClusterName ..." -ForegroundColor Cyan
k3d kubeconfig merge $ClusterName --kubeconfig-merge-default
kubectl config use-context "k3d-$ClusterName"

Write-Host "-> Ensuring API server address is 127.0.0.1 ..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
$currentServer = kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}" 2>$null
$ErrorActionPreference = "Stop"
if ($currentServer -match "host\.docker\.internal:(\d+)") {
    $port = $Matches[1]
    $newServer = "https://127.0.0.1:$port"
    Write-Host "   Rewriting $currentServer -> $newServer" -ForegroundColor DarkGray
    kubectl config set-cluster "k3d-$ClusterName" --server=$newServer
}

Write-Host "-> Waiting for API server to be ready (this can take ~30s)..." -ForegroundColor Cyan
$retries = 0
$apiReady = $false
while (-not $apiReady) {
    $retries++
    if ($retries -gt 30) {
        Write-Error "Timed out waiting for API server after 90s."
        exit 1
    }
    $ErrorActionPreference = "Continue"
    $out = kubectl cluster-info 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"

    if ($exitCode -eq 0) {
        $apiReady = $true
    } else {
        Write-Host "   [$retries/30] Not ready yet, retrying in 3s..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
    }
}
Write-Host "v API server is ready." -ForegroundColor Green

Write-Host "-> Building Docker image: $ImageName ..." -ForegroundColor Cyan
docker build -t $ImageName .

Write-Host "-> Pushing image to local registry..." -ForegroundColor Cyan
docker push $ImageName

$ErrorActionPreference = "Continue"
$existing = kubectl get ns ingress-nginx --ignore-not-found 2>$null
$ErrorActionPreference = "Stop"
if (-not $existing) {
    Write-Host "-> Installing ingress-nginx..." -ForegroundColor Cyan
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/cloud/deploy.yaml
    Write-Host "   Waiting for ingress-nginx controller pod to be ready..."
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
} else {
    Write-Host "v ingress-nginx already installed." -ForegroundColor Green
}

Write-Host "-> Applying secrets from .dev.env..." -ForegroundColor Cyan
& "$PSScriptRoot\k8s-apply-secrets.ps1"

Write-Host "-> Applying Kubernetes manifests..." -ForegroundColor Cyan
kubectl apply -f "$K8sManifests/deployment.yaml"
kubectl apply -f "$K8sManifests/service.yaml"
kubectl apply -f "$K8sManifests/ingress.yaml"

Write-Host "-> Waiting for deployment rollout..." -ForegroundColor Cyan
kubectl rollout status deployment/python-project --timeout=60s

Write-Host ""
Write-Host "Done! App available at: http://localhost:8082" -ForegroundColor Green
Write-Host "   kubectl context: k3d-$ClusterName"