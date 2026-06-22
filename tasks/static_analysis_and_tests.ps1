.\scripts\format_and_lint.ps1 ; 

uv run pytest tests/ --cov=src -vv ; 
uv run pytest tests2/ --cov=src2 -vv ; 

uv run alembic upgrade head ; 
uv run alembic downgrade base ; 
uv run alembic upgrade head ; 

uv run python src2\manage.py migrate ; 
