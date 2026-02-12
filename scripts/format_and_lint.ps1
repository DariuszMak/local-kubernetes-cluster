uv run ruff format test src
uv run ruff check --fix test src
uv run ruff check --fix --unsafe-fixes test src
uv run ruff check --fix --select I test src

uv run pip-audit
uv run ruff check test src
uv run ruff format --check test src

uv run mypy --strict test src

# uv run mypy --explicit-package-bases test src
# uv run mypy --explicit-package-bases --check-untyped-defs test src
# uv run mypy --strict test src