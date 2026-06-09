docker compose up -d sonarqube sonardb ; 

do {
    Start-Sleep -Seconds 5

    try {
        $status = Invoke-RestMethod `
            -Uri "http://127.0.0.1:9000/api/system/status" `
            -Method Get
    }
    catch {
        $status = $null
    }

} until ($status.status -eq "UP")

$oldPassword = "admin"
$newPassword = "Admin1@Admin1@"

$pair = "admin:$oldPassword"
$encoded = [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes($pair)
)

$headers = @{
    Authorization = "Basic $encoded"
}

Invoke-RestMethod `
    -Uri "http://127.0.0.1:9000/api/users/change_password" `
    -Method Post `
    -Headers $headers `
    -Body @{
        login = "admin"
        previousPassword = $oldPassword
        password = $newPassword
    }

$newPair = "admin:$newPassword"
$newEncoded = [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes($newPair)
)

$newHeaders = @{
    Authorization = "Basic $newEncoded"
}

# Generate token
$tokenName = "global-analysis-token"

$tokenResponse = Invoke-RestMethod `
    -Uri "http://127.0.0.1:9000/api/user_tokens/generate" `
    -Method Post `
    -Headers $newHeaders `
    -Body @{
        name = $tokenName
        type = "GLOBAL_ANALYSIS_TOKEN"
    }

$token = $tokenResponse.token

@"
SONAR_HOST_URL=http://sonarqube:9000
SONAR_TOKEN=$token
"@ | Out-File -Encoding utf8 ".sonar.env"

$scannerOutput = docker run --rm `
    --network sonar-network `
    --env-file .sonar.env `
    -v "${PWD}:/usr/src" `
    -w /usr/src `
    sonarsource/sonar-scanner-cli 2>&1

$scannerOutput

$reportUrls = ($scannerOutput |
    Select-String "http://\S+") |
    ForEach-Object { $_.Matches.Value }

foreach ($url in $reportUrls) {
    $localUrl = $url `
        -replace "http://sonarqube:9000", "http://127.0.0.1:9000" `
        -replace "http://host.docker.internal:9000", "http://127.0.0.1:9000"

    Start-Process $localUrl
}
