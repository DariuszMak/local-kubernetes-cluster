import os
import sys

from src.helpers.config.config import get_settings

settings = get_settings()


def run() -> None:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")
    sys.path.insert(0, "src2")

    import uvicorn

    uvicorn.run(
        "src2.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )


if __name__ == "__main__":
    run()
