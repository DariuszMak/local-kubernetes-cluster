from dataclasses import dataclass
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from src2.helpers.config.env_loader_mixin import EnvLoaderMixin


@dataclass(frozen=True)
class Config(EnvLoaderMixin):
    log_file: str = "app2.log"


class Settings(BaseSettings):
    app_name: str = "App2 API"
    debug: bool = True
    version: str = "1.0.0"
    database_url: str = "sqlite+aiosqlite:///./app2.db"
    host: str = Field(default="127.0.0.1", validation_alias="HOST2")
    port: int = Field(default=8002, validation_alias="PORT2")

    model_config = SettingsConfigDict(
        env_file=".dev.env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
