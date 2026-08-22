"""Server-owned Plan Policy domain model."""

from datetime import UTC, datetime
from enum import StrEnum
from typing import Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class PlanKey(StrEnum):
    """Server-recognized plan identifiers."""

    FREE = "free"


class PlanPolicy(BaseModel):
    """An immutable, versioned snapshot of server-owned limits."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    plan_key: PlanKey
    policy_version: int = Field(gt=0)
    active_voice_limit: int = Field(gt=0)
    monthly_clone_limit: int = Field(ge=0)
    monthly_generation_limit_ms: int = Field(gt=0)
    generation_character_limit: int = Field(gt=0)
    generation_concurrency_limit: int = Field(gt=0)
    reference_audio_max_bytes: int = Field(gt=0)
    reference_audio_min_ms: int = Field(gt=0)
    reference_audio_max_ms: int = Field(gt=0)
    effective_at: datetime
    retired_at: datetime | None = None

    @field_validator("effective_at", "retired_at")
    @classmethod
    def require_utc_datetime(cls, value: datetime | None) -> datetime | None:
        """Reject naive timestamps and normalize aware timestamps to UTC."""
        if value is None:
            return None
        if value.tzinfo is None or value.utcoffset() is None:
            msg = "Plan Policy timestamps must include a UTC offset."
            raise ValueError(msg)
        return value.astimezone(UTC)

    @model_validator(mode="after")
    def validate_bounds(self) -> Self:
        """Validate limits that depend on another policy field."""
        if self.reference_audio_max_ms < self.reference_audio_min_ms:
            msg = "Reference audio maximum must not precede its minimum."
            raise ValueError(msg)
        if self.retired_at is not None and self.retired_at <= self.effective_at:
            msg = "Plan Policy retirement must follow its effective time."
            raise ValueError(msg)
        return self


def free_plan_policy() -> PlanPolicy:
    """Return the initial Free policy defined by the implementation plan."""
    return PlanPolicy(
        plan_key=PlanKey.FREE,
        policy_version=1,
        active_voice_limit=2,
        monthly_clone_limit=2,
        monthly_generation_limit_ms=600_000,
        generation_character_limit=1_000,
        generation_concurrency_limit=1,
        reference_audio_max_bytes=10 * 1024 * 1024,
        reference_audio_min_ms=10_000,
        reference_audio_max_ms=30_000,
        effective_at=datetime(2026, 1, 1, tzinfo=UTC),
    )
