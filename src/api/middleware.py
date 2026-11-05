"""HTTP request/response middleware for structured logging.

This middleware logs every HTTP request with method, path, status code, and duration.
Logs are emitted as JSON via structlog, which are picked up by:
  - Filebeat (local dev) -> Elasticsearch -> Kibana
  - OTEL Collector (K8s) -> Loki -> Grafana
  - Promtail (K8s) -> Loki -> Grafana
"""

import time

import structlog

logger = structlog.get_logger(__name__)


class HTTPLogMiddleware:
    """FastAPI middleware that logs HTTP request/response details."""

    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start_time = time.perf_counter()

        # Capture the request method and path
        method = scope.get("method", "")
        path = scope.get("path", "")
        query_string = scope.get("query_string", b"").decode("utf-8", errors="replace")

        logger.info(
            "http_request_start",
            method=method,
            path=path,
            query_string=query_string,
            service="python-api",
        )

        # Use a wrapper to capture the actual response
        response_started = False
        response_status = 0

        async def capture_send(message):
            nonlocal response_started, response_status
            if message["type"] == "http.response.start":
                response_started = True
                response_status = message.get("status", 0)
            await send(message)

        try:
            await self.app(scope, receive, capture_send)
        except Exception as exc:
            duration_ms = (time.perf_counter() - start_time) * 1000
            logger.error(
                "http_request_error",
                method=method,
                path=path,
                query_string=query_string,
                status_code=500,
                duration_ms=round(duration_ms, 2),
                service="python-api",
                detail=str(exc),
            )
            raise

        duration_ms = (time.perf_counter() - start_time) * 1000

        if response_started:
            logger.info(
                "http_request_complete",
                method=method,
                path=path,
                query_string=query_string,
                status_code=response_status,
                duration_ms=round(duration_ms, 2),
                service="python-api",
            )
        else:
            # Response was not started (e.g., WebSocket upgrade)
            logger.info(
                "http_request_no_response",
                method=method,
                path=path,
                query_string=query_string,
                duration_ms=round(duration_ms, 2),
                service="python-api",
            )
