$MaxWaitSeconds = 180
$RetryInterval  = 5
$Elapsed        = 0
$Ready          = $false

Write-Host "-> Waiting for API at http://127.0.0.1:8003 ..." -ForegroundColor Cyan

while (-not $Ready) {
    if ($Elapsed -ge $MaxWaitSeconds) {
        Write-Error "API did not become ready after ${MaxWaitSeconds}s. Aborting."
        exit 1
    }

    try {
        $response = Invoke-WebRequest `
            -Uri "http://127.0.0.1:8003/health/readiness" `
            -Method Get `
            -UseBasicParsing `
            -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            $Ready = $true
        }
    }
    catch {
        Write-Host "   [${Elapsed}s/${MaxWaitSeconds}s] Not ready yet..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $RetryInterval
        $Elapsed += $RetryInterval
    }
}

Write-Host "-> API is ready. Waiting for port-forward to stabilize..." -ForegroundColor Cyan

$StableCount    = 0
$RequiredStable = 3

while ($StableCount -lt $RequiredStable) {
    Start-Sleep -Seconds 2

    try {
        $response = Invoke-WebRequest `
            -Uri "http://127.0.0.1:8003/health/readiness" `
            -Method Get `
            -UseBasicParsing `
            -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            $StableCount++
            Write-Host "   Stable check $StableCount/$RequiredStable" -ForegroundColor DarkGray
        } else {
            $StableCount = 0
        }
    }
    catch {
        $StableCount = 0
        Write-Host "   Stability check failed, resetting..." -ForegroundColor DarkGray
    }
}

Write-Host "-> API is stable and ready for tests." -ForegroundColor Green
