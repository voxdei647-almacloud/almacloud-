import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    POSTGRES_USER: str = "alma_dev"
    POSTGRES_PASSWORD: str = ""
    POSTGRES_APP_USER: str = "alma_app"
    POSTGRES_APP_PASSWORD: str = ""
    POSTGRES_HOST: str = "127.0.0.1"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "alma_cloud"

    VALKEY_HOST: str = "127.0.0.1"
    VALKEY_PORT: int = 6379
    VALKEY_PASSWORD: str = ""

    OPENSEARCH_HOST: str = "127.0.0.1"
    OPENSEARCH_PORT: int = 9200
    OPENSEARCH_USER: str = "admin"
    OPENSEARCH_PASSWORD: str = ""

    JWT_ALGORITHM: str = "RS256"
    JWT_PRIVATE_KEY_PATH: str = "secrets/jwt_private.pem"
    JWT_PUBLIC_KEY_PATH: str = "secrets/jwt_public.pem"
    JWT_ISSUER: str = "alma-cloud"
    JWT_AUDIENCE: str = "alma-api"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    ENABLE_ML_DETECTION: bool = False

    @property
    def DATABASE_URL(self) -> str:
        user = self.POSTGRES_APP_USER or os.getenv("POSTGRES_APP_USER") or "alma_app"
        password = self.POSTGRES_APP_PASSWORD or os.getenv("POSTGRES_APP_PASSWORD")

        if not password:
            app_secret = Path("secrets/postgres_app_password")
            if app_secret.is_file() and app_secret.read_text().strip():
                password = app_secret.read_text().strip()
            elif self.POSTGRES_PASSWORD:
                password = self.POSTGRES_PASSWORD
                user = self.POSTGRES_USER or "alma_dev"
            else:
                pg_secret = Path("secrets/postgres_password")
                if pg_secret.is_file() and pg_secret.read_text().strip():
                    password = pg_secret.read_text().strip()
                    user = self.POSTGRES_USER or "alma_dev"
                else:
                    password = ""

        return (
            f"postgresql+asyncpg://{user}:{password}"
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

    @property
    def OPENSEARCH_AUTH_PASSWORD(self) -> str:
        if self.OPENSEARCH_PASSWORD:
            return self.OPENSEARCH_PASSWORD
        os_secret = Path("secrets/opensearch_password")
        if os_secret.is_file():
            return os_secret.read_text().strip()
        return "admin"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
