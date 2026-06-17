.\scripts\format_and_lint.ps1 ; 

uv run pytest tests/ tests2/ --cov=src --cov=src2 -vv ; 

uv run alembic upgrade head ; 
uv run alembic -c alembic2.ini upgrade head ; 
uv run alembic downgrade base ; 
uv run alembic -c alembic2.ini downgrade base ; 
uv run alembic upgrade head ; 
uv run alembic -c alembic2.ini upgrade head ; 