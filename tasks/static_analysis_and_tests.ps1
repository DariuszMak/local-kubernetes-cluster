.\scripts\format_and_lint.ps1 ; 

uv run pytest tests/ tests2/ --cov=src --cov=src2 -vv --import-mode=importlib; 

uv run alembic upgrade head ; 
uv run alembic downgrade base ; 
uv run alembic upgrade head ; 

uv run python src2\manage.py migrate ; 
