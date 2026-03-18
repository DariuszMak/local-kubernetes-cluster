import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)


def load_dev_env(env_path: str = "dev.env") -> dict[str, str]:
    """Load key=value pairs from a .env file into os.environ. Returns loaded vars."""
    loaded: dict[str, str] = {}
    path = Path(env_path)
    if not path.exists():
        logger.warning("Env file not found: %s", env_path)
        return loaded
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip()
            if os.getenv(key) is None:
                os.environ[key] = value
                logger.debug("Loaded env var: %s", key)
            else:
                logger.debug("Skipped env var (already set): %s", key)
            loaded[key] = value
    logger.info("Loaded %d var(s) from %s", len(loaded), env_path)
    return loaded


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    load_dev_env()
