$MaxWaitSeconds = 120
$RetryInterval  = 3
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
            -Uri "http://127.0.0.1:8003/health/" `
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

Write-Host "-> API is ready." -ForegroundColor Green