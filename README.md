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


## Code linting

```commandline
.venv\Scripts\Activate.ps1 ; 
$env:PYTHONPATH="." ; 

clear ; 

uv run pip-audit ; 
uv run ruff check test src ; 
uv run ruff format --check test src ; 

uv run mypy --strict test src ; 

# uv run mypy --explicit-package-bases test src ; 
# uv run mypy --explicit-package-bases --check-untyped-defs test src ; 
# uv run mypy --strict test src ; 
```


## Code autoformat

```commandline
.venv\Scripts\Activate.ps1 ; 
$env:PYTHONPATH="." ; 

clear ; 

uv run ruff format test src ; 

uv run ruff check --fix test src ; 
uv run ruff check --fix --unsafe-fixes test src ; 
uv run ruff check --fix --select I test src ; 
```