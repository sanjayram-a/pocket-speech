"""Environment-backed application settings."""

from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Validated process configuration loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_prefix="POCKET_SPEECH_",
        env_ignore_empty=True,
        extra="ignore",
    )

    environment: Literal["local", "staging", "production"] = "local"
    firebase_project_id: str = Field(min_length=1)
    firebase_check_revoked: bool = True
