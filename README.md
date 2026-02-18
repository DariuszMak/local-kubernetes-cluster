# Python project

## Requirements

- [UV](https://github.com/astral-sh/uv) package manager


## Local development (Windows PowerShell):

You can also use VSCode `settings.json` and `launch.json` files to run the project (choose interpreter created by UV).

## Fast native Windows development:

```commandline
deactivate ; 
clear ; 

uv self update ; 
uv cache clean ; 

git reset --hard HEAD ; 
git clean -x -d -f ; 

uv python install 3.11 ; 
uv python pin 3.11 ; 
uv sync --dev --no-cache ; 
uv lock ; 

##### STATIC ANALYSIS & TESTS

.venv\Scripts\Activate.ps1 ; 
$env:PYTHONPATH="." ; 

.\scripts\format_and_lint.ps1 ; 

pytest test/ --cov=src -vv ; 

##### RUN APPLICATION LOCALLY

Start-Process uv -ArgumentList "run", "python", "src\main.py" ; 
```
