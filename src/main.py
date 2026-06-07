from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from src.api.router import api_router
from src.core.config import get_settings
from src.core.exceptions import global_exception_handler
from src.core.logging import configure_logging

configure_logging()


settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    description="Production-ready FastAPI template for recruitment tasks.",
)

app.include_router(api_router)

app.add_exception_handler(Exception, global_exception_handler)

app.mount("/static", StaticFiles(directory="src/static"), name="static")


@app.get("/favicon.ico", include_in_schema=False)
async def favicon() -> FileResponse:
    return FileResponse(Path("src/static/favicon.ico"))


def run() -> None:
    import uvicorn
    uvicorn.run(
        "src.main:app",
        host="0.0.0.0", 
        port=8001,
        reload=settings.debug,
    )


if __name__ == "__main__":
    run()
