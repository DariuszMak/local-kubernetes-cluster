FROM python:3.14-slim

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY pyproject.toml ./
COPY uv.lock ./
RUN uv sync --no-dev --frozen --compile-bytecode

COPY alembic.ini ./
COPY alembic/ ./alembic/
COPY src/ ./src/
COPY .dev.env ./.dev.env

ENV PYTHONPATH=.
ENV PATH="/app/.venv/bin:$PATH"

CMD ["sh", "-c", "alembic upgrade head && uv run alembic downgrade base && alembic upgrade head && python src/main.py"]