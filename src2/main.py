import os
import sys


def main() -> None:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")
    sys.path.insert(0, "src2")

    import uvicorn

    uvicorn.run(
        "core.asgi:application",
        host="127.0.0.1",
        port=int(os.environ.get("PORT", 8000)),
        reload=os.environ.get("DEBUG", "true").lower() == "true",
        log_level="info",
    )


if __name__ == "__main__":
    main()
