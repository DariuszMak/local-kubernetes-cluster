.\scripts\k3d-up.ps1 ;
.\scripts\app2-image-build-push.ps1 ;

Start-Process "http://localhost:8082" ; 

kubectl get deployments -A --no-headers `
| ForEach-Object {
    $parts = $_ -split '\s+'
    $ns = $parts[0]
    $name = $parts[1]

    Write-Host "`n=== $ns / $name ==="
    kubectl tree deployment $name -n $ns
}
