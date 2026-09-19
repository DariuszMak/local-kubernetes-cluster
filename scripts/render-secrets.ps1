#!/usr/bin/env pwsh

param(
    [ValidateSet("dev", "staging", "prod", "app2-dev", "app2-staging", "app2-prod")]
    [string]$Overlay = "dev",

    [string]$SourceEnv = ".dev.env"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SecretKeys = @("EXAMPLE_VARIABLE_NAME")

$OverlayPath = "k8s/kustomize/overlays/$Overlay"

$EnvSuffix = switch -Regex ($Overlay) {
    "staging$" { "staging" }
    "prod$"    { "prod" }
    default    { "dev" }
}

$OutFile = Join-Path $OverlayPath ".$EnvSuffix.secrets.env"

if (-not (Test-Path $OverlayPath)) {
    Write-Error "Overlay path not found: $OverlayPath"
    exit 1
}

$envMap = @{}
if (Test-Path $SourceEnv) {
    foreach ($line in Get-Content $SourceEnv) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#") -or $line -notmatch "=") { continue }
        $parts = $line -split "=", 2
        $envMap[$parts[0].Trim()] = $parts[1].Trim()
    }
} else {
    Write-Warning "$SourceEnv not found, writing empty values."
}

$lines = [System.Collections.Generic.List[string]]::new()
foreach ($key in $SecretKeys) {
    $value = ""
    if ($envMap.ContainsKey($key)) { $value = $envMap[$key] }
    $lines.Add("$key=$value")
}

$lines | Set-Content $OutFile -Encoding UTF8

Write-Host "-> Wrote $($lines.Count) secret(s) to $OutFile" -ForegroundColor DarkGray
