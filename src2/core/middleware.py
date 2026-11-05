"""HTTP request/response middleware for Django (src2).

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
    """Django middleware that logs HTTP request/response details."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        start_time = time.perf_counter()

        method = request.method
        path = request.path
        query_string = request.META.get("QUERY_STRING", "")

        logger.info(
            "http_request_start",
            method=method,
            path=path,
            query_string=query_string,
            service="python-app2",
        )

        response = self.get_response(request)

        duration_ms = (time.perf_counter() - start_time) * 1000

        logger.info(
            "http_request_complete",
            method=method,
            path=path,
            query_string=query_string,
            status_code=response.status_code,
            duration_ms=round(duration_ms, 2),
            service="python-app2",
        )

        return response
