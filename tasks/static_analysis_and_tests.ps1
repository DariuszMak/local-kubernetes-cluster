.\scripts\format_and_lint.ps1 ; 

uv run pytest tests/ --cov=src -vv ; 

uv run alembic upgrade head ; uv run alembic downgrade base ; uv run alembic upgrade head ; 