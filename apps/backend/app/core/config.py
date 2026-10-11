import os
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    POSTGRES_USER: str = "alma_dev"
    POSTGRES_PASSWORD: str = ""
    POSTGRES_HOST: str = "127.0.0.1"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "alma_cloud"

    @property
    def DATABASE_URL(self) -> str:
        app_user = os.getenv("POSTGRES_APP_USER", "alma_app")
        app_pass = os.getenv("POSTGRES_APP_PASSWORD", self.POSTGRES_PASSWORD)
        return (
            f"postgresql+asyncpg://{app_user}:{app_pass}"
            f"@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
