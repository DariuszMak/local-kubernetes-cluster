import logging
from typing import Any

from rest_framework.response import Response
from rest_framework.views import exception_handler

logger = logging.getLogger("api")


def global_exception_handler(exc: Exception, context: dict[str, Any]) -> Response:
    response = exception_handler(exc, context)
    if response is not None:
        return response
    logger.exception("Unhandled exception occurred")
    return Response({"detail": "Internal Server Error"}, status=500)


class DuplicateEmailError(Exception):
    def __init__(self, email: str) -> None:
        self.email = email
        super().__init__(f"User with email '{email}' already exists.")
