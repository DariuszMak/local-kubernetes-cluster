uv run ruff format tests src
uv run ruff check --fix tests src
uv run ruff check --fix --unsafe-fixes tests src
uv run ruff check --fix --select I tests src

uv run pip-audit
uv run ruff check tests src
uv run ruff format --check tests src

uv run mypy --strict tests src

# uv run mypy --explicit-package-bases tests src
# uv run mypy --explicit-package-bases --check-untyped-defs tests src
# uv run mypy --strict tests src