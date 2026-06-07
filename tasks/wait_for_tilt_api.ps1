do {
    Start-Sleep -Seconds 3

    try {
        $api = Invoke-RestMethod `
            -Uri "http://127.0.0.1:8003/openapi.json" `
            -Method Get
    }
    catch {
        $api = $null
    }

} until ($api)
