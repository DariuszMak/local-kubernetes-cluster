uv run ruff format alembic src tests
uv run ruff check --fix alembic src tests
uv run ruff check --fix --unsafe-fixes alembic src tests
uv run ruff check --fix --select I alembic src tests

uv run pip-audit
uv run ruff check alembic src tests
uv run ruff format --check alembic src tests

uv run vulture src tests --min-confidence 80

uv run mypy --strict alembic src tests

# uv run mypy --explicit-package-bases alembic src tests
# uv run mypy --explicit-package-bases --check-untyped-defs alembic src tests
# uv run mypy --strict alembic src tests