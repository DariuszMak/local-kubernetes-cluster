# syntax=docker/dockerfile:1
FROM python:3.14-slim

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency manifests first for layer caching
COPY pyproject.toml ./
COPY uv.lock* ./

# Install only production dependencies (no dev group)
RUN uv sync --no-dev --frozen

# Copy application source
COPY src/ ./src/

ENV PYTHONPATH=.

# Adjust this if your entrypoint differs
CMD ["uv", "run", "python", "src/main.py"]
