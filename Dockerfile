# syntax=docker/dockerfile:1
FROM python:3.14-slim

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY pyproject.toml ./
COPY uv.lock ./
RUN uv sync --no-dev --frozen

COPY alembic.ini ./
COPY alembic/ ./alembic/
COPY src/ ./src/

ENV PYTHONPATH=.

CMD ["sh", "-c", "uv run alembic upgrade head && uv run python src/main.py"]
