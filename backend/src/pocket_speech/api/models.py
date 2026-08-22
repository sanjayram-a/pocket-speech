"""Typed HTTP success contracts."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from pocket_speech.domain.plan_policy import PlanKey, PlanPolicy


class HealthResponse(BaseModel):
    """Public liveness response."""

    model_config = ConfigDict(extra="forbid")

    status: str
    service: str
    version: str


class UserIdentityResponse(BaseModel):
    """Current verified Firebase identity without fabricated persistence IDs."""

    model_config = ConfigDict(extra="forbid")

    firebase_uid: str


class UsageSnapshotResponse(BaseModel):
    """Current counters for one half-open UTC monthly period."""

    model_config = ConfigDict(extra="forbid")

    period_start: datetime
    period_end: datetime
    generated_ms: int = Field(ge=0)
    successful_clones: int = Field(ge=0)
    active_voices: int = Field(ge=0)
    active_generations: int = Field(ge=0)


class MeResponse(BaseModel):
    """Authenticated User bootstrap response."""

    model_config = ConfigDict(extra="forbid")

    user: UserIdentityResponse
    plan_key: PlanKey
    policy: PlanPolicy
    usage: UsageSnapshotResponse


class UsageResponse(BaseModel):
    """Current Usage together with the effective server policy."""

    model_config = ConfigDict(extra="forbid")

    plan_key: PlanKey
    policy: PlanPolicy
    usage: UsageSnapshotResponse
