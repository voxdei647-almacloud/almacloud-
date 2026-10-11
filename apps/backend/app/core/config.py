import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    POSTGRES_USER: str = "alma_dev"
    POSTGRES_PASSWORD: str = ""
    POSTGRES_HOST: str = "127.0.0.1"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "alma_cloud"

    VALKEY_HOST: str = "127.0.0.1"
    VALKEY_PORT: int = 6379
    VALKEY_PASSWORD: str = ""

    @property
    def DATABASE_URL(self) -> str:
        app_user = os.getenv("POSTGRES_APP_USER", "alma_app")
        app_pass = os.getenv("POSTGRES_APP_PASSWORD", self.POSTGRES_PASSWORD)
        return (
            f"postgresql+asyncpg://{app_user}:{app_pass}"
            f"@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    @property
    def VALKEY_AUTH_PASSWORD(self) -> str:
        if self.VALKEY_PASSWORD:
            return self.VALKEY_PASSWORD
        valkey_secret = Path("secrets/valkey_password")
        if valkey_secret.is_file():
            return valkey_secret.read_text().strip()
        return ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
