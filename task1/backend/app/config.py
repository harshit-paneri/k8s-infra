"""Application configuration loaded from environment variables."""

import os
from urllib.parse import quote_plus


class Settings:
    """Central configuration for the Dodo Payments backend."""

    APP_NAME: str = os.getenv("APP_NAME", "dodo-payments-api")
    APP_VERSION: str = os.getenv("APP_VERSION", "1.0.0")
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Database
    DB_HOST: str = os.getenv("DB_HOST", "localhost")
    DB_PORT: int = int(os.getenv("DB_PORT", "5432"))
    DB_NAME: str = os.getenv("DB_NAME", "dodo_payments")
    DB_USER: str = os.getenv("DB_USER", "postgres")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "postgres")

    @property
    def database_url(self) -> str:
        # URL-encode password to handle special chars like @
        encoded_password = quote_plus(self.DB_PASSWORD)
        return (
            f"postgresql://{self.DB_USER}:{encoded_password}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )

    # Observability
    JAEGER_HOST: str = os.getenv("JAEGER_HOST", "jaeger-collector.monitoring.svc.cluster.local")
    JAEGER_PORT: int = int(os.getenv("JAEGER_PORT", "6831"))
    ENABLE_TRACING: bool = os.getenv("ENABLE_TRACING", "false").lower() == "true"

    # Server
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))


settings = Settings()
