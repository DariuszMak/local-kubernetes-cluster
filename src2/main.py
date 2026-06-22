import os
import sys

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

import structlog
from src2.helpers.logging_setup import logging_setup
from src2.helpers.config.config import get_settings

logging_setup()

logger = structlog.get_logger(__name__)

settings = get_settings()


def run() -> None:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")

    import uvicorn

    uvicorn.run(
        "core.asgi:application",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )


if __name__ == "__main__":
    run()
