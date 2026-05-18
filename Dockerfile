# syntax=docker/dockerfile:1
FROM python:3.14-slim

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency manifests first for layer caching
COPY pyproject.toml ./
COPY uv.lock* ./

# Install only production dependencies.
# If uv.lock exists (committed or generated), use --frozen for reproducibility.
# Falls back to a plain sync if no lockfile is present.
RUN if [ -f uv.lock ]; then uv sync --no-dev --frozen; else uv sync --no-dev; fi

# Copy application source
COPY src/ ./src/

ENV PYTHONPATH=.

# Adjust this if your entrypoint differs
CMD ["uv", "run", "python", "src/main.py"]