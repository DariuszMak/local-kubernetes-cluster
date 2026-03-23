# Python project

## Requirements

- [UV](https://github.com/astral-sh/uv) package manager


## Local development (Windows PowerShell):

You can also use VSCode `settings.json` and `launch.json` files to run the project (choose interpreter created by UV).

## Fast native Windows development:

```commandline
deactivate ; 
clear ; 

# $ports = 8000, 8001
# 
# foreach ($port in $ports) {
#     $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
#     if ($conns) {
#         $conns | Select-Object -ExpandProperty OwningProcess -Unique |
#             Where-Object { $_ -gt 0 } |
#             ForEach-Object {
#                 Write-Host "Port $port is used by PID $_. Killing..."
#                 Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
#             }
#     } else {
#         Write-Host "No process is using port $port."
#     }
# }

uv self update ; 
uv cache clean ; 

git reset --hard HEAD ; 
git clean -x -d -f ; 

uv python install 3.14 ; 
uv python pin 3.14 ; 
uv sync --dev --no-cache ; 
uv lock ; 

##### STATIC ANALYSIS & TESTS

.venv\Scripts\Activate.ps1 ; 

Get-Content dev.env | ForEach-Object { if ($_ -match '^\s*([^=]+?)\s*=\s*"?([^"]*)"?') { [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], [System.EnvironmentVariableTarget]::Process) } else { Write-Warning "Invalid entry: '$_'" } } ; 
Get-ChildItem Env: ; 

.\scripts\format_and_lint.ps1 ; 

pytest tests/ --cov=src -vv ; 

##### RUN APPLICATION LOCALLY

Start-Process uv -ArgumentList "run", "python", "src\main.py" ; 
```
