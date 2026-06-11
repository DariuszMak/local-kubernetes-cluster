from pathlib import Path

import structlog
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from src.api.router import api_router
from src.helpers.config.config import get_settings
from src.helpers.exceptions import global_exception_handler
from src.helpers.logging_setup import logging_setup

logging_setup()

logger = structlog.get_logger(__name__)

settings = get_settings()


app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    description="Production-ready FastAPI template for recruitment tasks.",
)

app.include_router(api_router)

app.add_exception_handler(Exception, global_exception_handler)

app.mount("/static", StaticFiles(directory="src/static"), name="static")

logger.info("FastAPI started", app_name=settings.app_name, version=settings.version)


@app.get("/favicon.ico", include_in_schema=False)
async def favicon() -> FileResponse:
    return FileResponse(Path("src/static/favicon.ico"))


def run() -> None:
    import uvicorn

    uvicorn.run(
        "src.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )


if __name__ == "__main__":
    run()
