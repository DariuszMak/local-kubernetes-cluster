$MaxWaitSeconds = 180
$RetryInterval  = 5
$Elapsed        = 0
$Ready          = $false

$HostUrl = "http://127.0.0.1:8002"
$HealthEndpoint = "$HostUrl/health/readiness"

Write-Host "-> Waiting for API at $HostUrl ..." -ForegroundColor Cyan

while (-not $Ready) {
    if ($Elapsed -ge $MaxWaitSeconds) {
        Write-Error "API did not become ready after ${MaxWaitSeconds}s. Aborting."
        exit 1
    }

    try {
        $tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port 8002 -WarningAction SilentlyContinue
        if (-not $tcp.TcpTestSucceeded) {
            Write-Host "   [${Elapsed}s] TCP not ready..." -ForegroundColor DarkGray
            Start-Sleep -Seconds $RetryInterval
            $Elapsed += $RetryInterval
            continue
        }
    }
    catch {
        Write-Host "   [${Elapsed}s] TCP check failed..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $RetryInterval
        $Elapsed += $RetryInterval
        continue
    }

    try {
        $response = Invoke-WebRequest `
            -Uri $HealthEndpoint `
            -Method Get `
            -UseBasicParsing `
            -TimeoutSec 5 `
            -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            $Ready = $true
        }
    }
    catch {
        Write-Host "   [${Elapsed}s/${MaxWaitSeconds}s] Not ready yet: $($_.Exception.Message)" -ForegroundColor DarkGray
        Start-Sleep -Seconds $RetryInterval
        $Elapsed += $RetryInterval
    }
}

Write-Host "-> API responded ready. Verifying stability window..." -ForegroundColor Cyan

$StableSecondsRequired = 15
$StableStart = $null
$StableCheckInterval = 2
$StableElapsed = 0

while ($true) {

    Start-Sleep -Seconds $StableCheckInterval
    $StableElapsed += $StableCheckInterval

    try {
        $response = Invoke-WebRequest `
            -Uri $HealthEndpoint `
            -Method Get `
            -UseBasicParsing `
            -TimeoutSec 5 `
            -ErrorAction Stop

        if ($response.StatusCode -eq 200) {

            if (-not $StableStart) {
                $StableStart = Get-Date
            }

            $stableDuration = (New-TimeSpan -Start $StableStart).TotalSeconds

            Write-Host "   Stable for ${stableDuration}s / ${StableSecondsRequired}s" -ForegroundColor DarkGray

            if ($stableDuration -ge $StableSecondsRequired) {
                break
            }
        }
        else {
            Write-Host "   Non-200 response, resetting stability..." -ForegroundColor DarkGray
            $StableStart = $null
        }
    }
    catch {
        Write-Host "   Stability check failed: $($_.Exception.Message)" -ForegroundColor DarkGray
        $StableStart = $null
    }

    if ($StableElapsed -ge $MaxWaitSeconds) {
        Write-Error "API did not stabilize after ${MaxWaitSeconds}s. Aborting."
        exit 1
    }
}

Start-Sleep -Seconds 5

Write-Host "-> API is stable and fully ready for integration tests." -ForegroundColor Green
