# Local kubernetes cluster

## Requirements

- [UV](https://github.com/astral-sh/uv) package manager
- [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/)
- [Vault](https://developer.hashicorp.com/vault/install)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [Helm](https://helm.sh/docs/intro/install/)
- [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [Task](https://taskfile.dev/installation/)
- [Tilt](https://docs.tilt.dev/install.html)


## Local development (Windows PowerShell):

You can also use VSCode `settings.json` and `launch.json` files to run the project (choose interpreter created by UV).

## Fast native Windows development:

```commandline

##### K3D

.\scripts\k3d-up.ps1 ; 

Start-Process "http://localhost:8082" ; 

kubectl get deployments -A --no-headers `
| ForEach-Object {
    $parts = $_ -split '\s+'
    $ns = $parts[0]
    $name = $parts[1]

    Write-Host "`n=== $ns / $name ==="
    kubectl tree deployment $name -n $ns
}

# .\scripts\k3d-redeploy.ps1 ; 
# .\scripts\k3d-down.ps1 ; 

##### KUSTOMIZE

.\scripts\kustomize-apply.ps1 -Overlay dev ; 
# .\scripts\kustomize-apply.ps1 -Overlay prod -DryRun ; 
# .\scripts\kustomize-apply.ps1 -Overlay staging ; 

##### TILT

Start-Process "http://localhost:10350" ; 
Start-Process "http://localhost:8003" ; 

.\scripts\tilt-up.ps1 ; 
# .\scripts\tilt-down.ps1 ; 
```