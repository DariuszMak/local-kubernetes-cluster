#!/usr/bin/env pwsh

Set-StrictMode -Version Latest

$ErrorActionPreference = "Stop"

$ClusterName  = "python-project"
$Registry     = "localhost:5001"
$K3dConfig    = "k3d-config.yaml"

$Apps = @(
    @{
        Name        = "app"
        ImageName   = "$Registry/python-project:local"
        Dockerfile  = "Dockerfile"
        HelmChart   = "tilt/helm-app"
        ReleaseName = "python-project"
    },
    @{
        Name        = "app2"
        ImageName   = "$Registry/python-project-app2:local"
        Dockerfile  = "Dockerfile.app2"
        HelmChart   = "tilt/helm-app2"
        ReleaseName = "python-project-app2"
    }
)

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

foreach ($app in $Apps) {
    Write-Host "-> Building Docker image ($($app.Name)): $($app.ImageName) ..." -ForegroundColor Cyan
    docker build -t $app.ImageName -f $app.Dockerfile .
    if ($LASTEXITCODE -ne 0) { Write-Error "Docker build failed for $($app.Name)."; exit 1 }

    Write-Host "-> Pushing image ($($app.Name)) to local registry..." -ForegroundColor Cyan
    docker push $app.ImageName
    if ($LASTEXITCODE -ne 0) { Write-Error "Docker push failed for $($app.Name)."; exit 1 }
}

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

foreach ($app in $Apps) {
    Write-Host "-> Deploying via Helm ($($app.Name)): $($app.ReleaseName) from $($app.HelmChart) ..." -ForegroundColor Cyan
    helm upgrade --install $app.ReleaseName $app.HelmChart `
        --wait --timeout 60s `
        @secretArgs
    if ($LASTEXITCODE -ne 0) { Write-Error "Helm deploy failed for $($app.Name)."; exit 1 }
}

Write-Host ""
Write-Host "Done! Apps available at:" -ForegroundColor Green
Write-Host "   app  : http://localhost:8082"
Write-Host "   app2 : http://localhost:8082/app2"
Write-Host "   kubectl context : k3d-$ClusterName"
foreach ($app in $Apps) {
    Write-Host "   helm release    : $($app.ReleaseName)"
    Write-Host "   helm history    : helm history $($app.ReleaseName)"
}
