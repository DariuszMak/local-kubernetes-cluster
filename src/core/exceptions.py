from typing import TYPE_CHECKING

from fastapi.responses import JSONResponse
import structlog

if TYPE_CHECKING:
    from fastapi import Request

logger = structlog.get_logger(__name__)


def global_exception_handler(_request: Request, _exc: Exception) -> JSONResponse:
    logger.exception("Unhandled exception occurred")

    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error"},
    )


class DuplicateEmailError(Exception):
    def __init__(self, email: str) -> None:
        self.email = email
        super().__init__(f"User with email '{email}' already exists.")
