"""Server settings. Importing this module never opens a database connection."""

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        extra="ignore",
        hide_input_in_errors=True,
    )

    app_name: str = "CCVO Backend"
    environment: Literal["development", "test", "production"] = "development"
    database_url: SecretStr | None = None
    migration_database_url: SecretStr | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
