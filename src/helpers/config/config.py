from dataclasses import dataclass
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from src.helpers.config.env_loader_mixin import EnvLoaderMixin


@dataclass(frozen=True)
class Config(EnvLoaderMixin):
    log_file: str = "app.log"


class Settings(BaseSettings):
    app_name: str = "App API"
    debug: bool = True
    version: str = "1.0.0"
    database_url: str = "sqlite+aiosqlite:///./app.db"
    host: str = Field(default="127.0.0.1", validation_alias="HOST")
    port: int = Field(default=8001, validation_alias="PORT")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
