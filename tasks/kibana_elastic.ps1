docker compose up -d elasticsearch filebeat kibana ; 

do {
    Start-Sleep -Seconds 5

    try {
        $es = Invoke-RestMethod `
            -Uri "http://127.0.0.1:9200" `
            -Method Get
    }
    catch {
        $es = $null
    }

} until ($es.cluster_name)

do {
    Start-Sleep -Seconds 5

    try {
        $kibana = Invoke-RestMethod `
            -Uri "http://127.0.0.1:5601/api/status" `
            -Headers @{ "kbn-xsrf" = "true" } `
            -Method Get
    }
    catch {
        $kibana = $null
    }

} until ($kibana.status.overall.level -eq "available")

do {
    Start-Sleep -Seconds 5

    try {
        $indices = Invoke-RestMethod `
            -Uri "http://127.0.0.1:9200/_cat/indices?format=json" `
            -Method Get
    }
    catch {
        $indices = $null
    }

} until ($indices.Count -gt 0)

Start-Process "http://127.0.0.1:9200" ; 
Start-Process "http://127.0.0.1:5601/app/discover#" ; 
