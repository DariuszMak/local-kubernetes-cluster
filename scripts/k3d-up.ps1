#!/usr/bin/env pwsh
# scripts/k3d-up.ps1
# Spins up k3d cluster, builds & pushes the image, applies all k8s manifests.
# Run from the project root.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ClusterName  = "python-project"
$Registry     = "localhost:5001"
$ImageName    = "$Registry/python-project:local"
$K3dConfig    = "k8s/k3d-config.yaml"
$K8sManifests = "k8s"

# 1. Create or start cluster
$clusterExists = k3d cluster list --no-headers 2>$null | Select-String $ClusterName
if (-not $clusterExists) {
    Write-Host "-> Creating k3d cluster from $K3dConfig ..." -ForegroundColor Cyan
    k3d cluster create --config $K3dConfig
} else {
    Write-Host "v Cluster '$ClusterName' already exists, starting if stopped..." -ForegroundColor Green
    k3d cluster start $ClusterName 2>$null
}

# 2. Switch kubectl context immediately after cluster is ready
Write-Host "-> Switching kubectl context to k3d-$ClusterName ..." -ForegroundColor Cyan
kubectl config use-context "k3d-$ClusterName"

# 3. Wait until the API server is actually reachable (suppress all output)
Write-Host "-> Waiting for API server to be ready..." -ForegroundColor Cyan
$retries = 0
do {
    Start-Sleep -Seconds 3
    $retries++
    if ($retries -gt 20) {
        Write-Error "Timed out waiting for API server after 60s."
        exit 1
    }
    # Redirect both stdout and stderr to null; check only exit code
    kubectl get nodes --request-timeout=5s 2>&1 | Out-Null
} until ($LASTEXITCODE -eq 0)
Write-Host "v API server is ready." -ForegroundColor Green

# 4. Build Docker image
Write-Host "-> Building Docker image: $ImageName ..." -ForegroundColor Cyan
docker build -t $ImageName .

# 5. Push image to local registry
Write-Host "-> Pushing image to local registry..." -ForegroundColor Cyan
docker push $ImageName

# 6. Install nginx ingress controller (if not present)
$existing = kubectl get ns ingress-nginx --ignore-not-found 2>$null
if (-not $existing) {
    Write-Host "-> Installing ingress-nginx..." -ForegroundColor Cyan
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/cloud/deploy.yaml
    Write-Host "   Waiting for ingress-nginx controller pod to be ready..."
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
} else {
    Write-Host "v ingress-nginx already installed." -ForegroundColor Green
}

# 7. Apply secrets (from .dev.env)
Write-Host "-> Applying secrets from .dev.env..." -ForegroundColor Cyan
& "$PSScriptRoot\k8s-apply-secrets.ps1"

# 8. Apply k8s manifests
Write-Host "-> Applying Kubernetes manifests..." -ForegroundColor Cyan
kubectl apply -f "$K8sManifests/deployment.yaml"
kubectl apply -f "$K8sManifests/service.yaml"
kubectl apply -f "$K8sManifests/ingress.yaml"

# 9. Wait for rollout
Write-Host "-> Waiting for deployment rollout..." -ForegroundColor Cyan
kubectl rollout status deployment/python-project --timeout=60s

Write-Host ""
Write-Host "Done! App available at: http://localhost:8080" -ForegroundColor Green
Write-Host "   kubectl context: k3d-$ClusterName"