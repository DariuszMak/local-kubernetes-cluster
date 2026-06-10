from dataclasses import dataclass

from src.helpers.config.env_loader_mixin import EnvLoaderMixin


@dataclass(frozen=True)
class Config(EnvLoaderMixin):
    log_file: str = "app.log"
