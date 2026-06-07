# syntax=docker/dockerfile:1
FROM python:3.14-slim

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY pyproject.toml ./
COPY uv.lock* ./

RUN if [ -f uv.lock ]; then uv sync --no-dev --frozen; else uv sync --no-dev; fi

COPY src/ ./src/

ENV PYTHONPATH=.

CMD ["uv", "run", "python", "src/main.py"]