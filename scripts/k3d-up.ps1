#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$ClusterName  = "python-project"
$Registry     = "localhost:5001"
$ImageName    = "$Registry/python-project:local"
$K3dConfig    = "k8s/k3d-config.yaml"
$HelmChart    = "helm"
$ReleaseName  = "python-project"

$SecretKeys = @("EXAMPLE_VARIABLE_NAME")

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

Write-Host "-> Waiting for API server to be ready..." -ForegroundColor Cyan
$retries = 0
$apiReady = $false
while (-not $apiReady) {
    $retries++
    if ($retries -gt 30) { Write-Error "Timed out waiting for API server."; exit 1 }
    $ErrorActionPreference = "Continue"
    $out = kubectl cluster-info 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($exitCode -eq 0) {
        $apiReady = $true
    } else {
        Write-Host "   [$retries/30] Not ready, retrying in 3s..." -ForegroundColor DarkGray
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
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
} else {
    Write-Host "v ingress-nginx already installed." -ForegroundColor Green
}

$envMap = @{}
foreach ($line in Get-Content ".dev.env") {
    $line = $line.Trim()
    if ($line -eq "" -or $line.StartsWith("#") -or $line -notmatch "=") { continue }
    $parts       = $line -split "=", 2
    $envMap[$parts[0].Trim()] = $parts[1].Trim()
}

$secretArgs = @()
foreach ($key in $SecretKeys) {
    if ($envMap.ContainsKey($key)) {
        $secretArgs += "--set=secrets.$key=$($envMap[$key])"
    } else {
        Write-Warning "Secret key '$key' not found in .dev.env"
    }
}

Write-Host "-> Deploying via Helm..." -ForegroundColor Cyan
helm upgrade --install $ReleaseName $HelmChart `
    --wait --timeout 60s `
    @secretArgs

Write-Host ""
Write-Host "Done! App available at: http://localhost:8082" -ForegroundColor Green
Write-Host "   kubectl context : k3d-$ClusterName"
Write-Host "   helm release    : $ReleaseName"
Write-Host "   helm history    : helm history $ReleaseName"
